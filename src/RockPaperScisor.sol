// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

/**
 * @author Theo6890
 * @notice Famous Rock, Paper & Scisor on-chain implementation with
 *         frontrunning protection using the commit-reveal pattern.
 * @dev Pull over Push strategy implemented, see:
 * https://github.com/fravoll/solidity-patterns/blob/master/docs/pull_over_push.md
 */
contract RockPaperScisor {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;

    enum Action {
        ROCK,
        PAPER,
        SCISOR
    }

    enum BattleResult {
        WIN,
        LOSS,
        EQUALITY
    }

    enum Stage {
        COMMIT,
        REVEAL,
        WITHDRAW_REWARDS
    }

    struct RevealData {
        address player;
        Action action;
        uint256 salt;
    }

    Stage public stage = Stage.COMMIT;

    uint256 public depositedETH;
    address public winner;
    /**
     * @notice As a string character is 1 byte long. Casting a string of 8
     *         characters to a byte20, to an address, will resut into a short
     *         address: 4 left bytes set using hex values, 16 right bytes
     *         padded with ZERO.
     *
     * Note: 1 bytes = 2 hex chars (excluding 0x)
     *
     * @dev We suppose such a short address will never be generated. Even if
     *      it is generated this address will never be able to withdraw funds,
     *      only the registered players will be able to withdraw.
     */
    address public constant EQUALITY_ADDR = address(bytes20("EQLT"));

    mapping(address => bytes32) private _commits;
    mapping(address => uint256) private _deposits;
    EnumerableSet.AddressSet private _players;

    // TEST: this modifier
    modifier requireStage(Stage _stage) {
        require(_stage == stage, "Wrong stage");
        _;
    }

    /**
     * @notice Function to play between two players
     * @dev Data are hashed using abi.encodePacked, as there is only one
     *      dynamic type (LOW) risk of collision , see SWC-133) & keccak256.
     *      For more details see `RockPaperScisorTest.t.sol`.setUp() function.
     *
     * @param saltedData Hashed data of one of the two players.
     */
    function commitOnlyTwoPlayers(
        bytes32 saltedData
    ) public payable requireStage(Stage.COMMIT) {
        address player = msg.sender;
        uint256 amount = msg.value;

        require(amount == 5 ether, "Deposit 5 ether");
        require(_commits[player] == bytes32(""), "Already commited");

        _commits[player] = saltedData;
        _deposits[player] += amount;
        depositedETH += amount;
        _players.add(player);

        // TODO: add event
        // emit Deposited(payee, amount);

        if (_players.length() == 2) _netxStage();
    }

    /**
     * @notice Reveals the winner of the game. Must pass data commited plain
     *         data and compare them with saved by hasing them.
     *
     * @param player1Data RevealData structure containing the player1 plain
     *        data
     * @param player2Data RevealData structure containing the player2 plain
     *        data
     */
    function revealWinnerTwoPlayers(
        RevealData calldata player1Data,
        RevealData calldata player2Data
    ) public requireStage(Stage.REVEAL) {
        // generate hashed data again to verify data authenticity
        bytes32 saltedHash1 = generateSaltedHashFrom(player1Data);
        bytes32 saltedHash2 = generateSaltedHashFrom(player2Data);

        require(
            saltedHash1 == _commits[player1Data.player],
            "P1: data mismatch"
        );
        require(
            saltedHash2 == _commits[player2Data.player],
            "P2: data mismatch"
        );

        // verify which action wins
        BattleResult resFirstPlayer = _isFirstActionWinning(
            player1Data.action,
            player2Data.action
        );

        // verify the winner and make it public
        _revealWinner(resFirstPlayer, player1Data.player, player2Data.player);

        /**
         * @dev PullPayment logic, to avoid DoS issues
         */
        _computeRewards();

        _netxStage();
    }

    /**
     * @notice Winner or participants (in case of EQUALITY) will claim their
     *         due. Pull over Push strategy.
     */
    function withdrawRewards() public requireStage(Stage.WITHDRAW_REWARDS) {
        address payable payee = payable(msg.sender);
        uint256 payment = _deposits[payee];

        require(payment > 0, "Game lost!");

        _deposits[payee] = 0;

        payee.sendValue(payment);

        //TODO: add event
        //emit Withdrawn(payee, payment);

        /**
         * @dev if ALL deposits have been withwrawn (on EQUALITY case == wait for
         * both players withdrawals)
         */
        if (
            (_deposits[_players.at(0)] == 0) &&
            (_deposits[_players.at(1)] == 0)
        ) __resetAllAfterAllWithdrawals();
    }

    function commitOf(address player) public view returns (bytes32) {
        return _commits[player];
    }

    function depositsOf(address payee) public view returns (uint256) {
        return _deposits[payee];
    }

    function playersLength() public view returns (uint256) {
        return _players.length();
    }

    /// @dev Generate hashed for a given `RevealData` structure.
    function generateSaltedHashFrom(
        RevealData calldata data
    ) public pure returns (bytes32 salted) {
        return
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked(data.player, data.action)),
                    data.salt
                )
            );
    }

    /**
     * @notice Rewards will be only computed if there is a winner. In the case
     *         of equality each player takes their deposit back.
     *         Otherwise if there is a winner they take it all
     */
    function _computeRewards() internal {
        // TEST: verify winner is ALWAYS set => can never be address(0) in any situation to address(0) check
        if ((winner != address(0)) && (winner != EQUALITY_ADDR)) {
            __resetDepositsOnWinsOnly();
            _deposits[winner] = depositedETH;
        }
    }

    function _netxStage() internal {
        stage = Stage(uint256(stage) + 1);
    }

    /**
     * @notice Reveal if player 1 wins, losses or is equal with player 2.
     * @dev On equality, players get half of the rewards. With two players
     *      only, it means they will get back there initial deposit.
     */
    function _revealWinner(
        BattleResult resFirstPlayer,
        address player1,
        address player2
    ) internal {
        // prettier-ignore
        if (resFirstPlayer == BattleResult.EQUALITY) winner = EQUALITY_ADDR;
        else if (resFirstPlayer == BattleResult.WIN) winner = player1;
        // if not an equality or win for player1, it is a win for player2
        else winner = player2;
    }

    ///@return BattleResult to know if `a1` wins over `a2` or not.
    function _isFirstActionWinning(
        Action a1,
        Action a2
    ) internal pure returns (BattleResult) {
        // Equality
        if (a1 == a2) return BattleResult.EQUALITY;
        // paper
        // - wins over rock
        // - losses over scisor
        else if ((a1 == Action.PAPER) && (a2 == Action.ROCK))
            return BattleResult.WIN;
        // rock
        // - wins over scisor
        // - losses over paper
        else if ((a1 == Action.ROCK) && (a2 == Action.SCISOR))
            return BattleResult.WIN;
        // scisor
        // - wins over paper
        // - losses rock
        else if ((a1 == Action.SCISOR) && (a2 == Action.PAPER))
            return BattleResult.WIN;
        // if it is not, an equality equality or a win, it is a loss
        else return BattleResult.LOSS;
    }

    /**
     * @dev Very sensitive functions, must only be used in this contract,
     *      enhance be private
     */

    ///@dev Reset all variables to default types values to play a new game.
    function __resetAllAfterAllWithdrawals() private {
        delete stage;
        delete depositedETH;
        ///@dev hardcoded length, see SWC-128
        for (uint i; i < 2; ++i) {
            delete _commits[_players.at(i)];
        }

        /**
         * @dev If there is a single winner deposits reset have already been
         *      triggered `_computeRewards` for loser(s), in `withdrawRewards`
         *      for winner).
         */
        if (winner == EQUALITY_ADDR) __resetDepositsOnWinsOnly();

        delete winner;

        delete _players;
    }

    ///@dev Reset all saved deposits.
    function __resetDepositsOnWinsOnly() private {
        ///@dev hardcoded length, see SWC-128
        for (uint i; i < 2; ++i) {
            _deposits[_players.at(i)] = 0;
        }
    }
}
