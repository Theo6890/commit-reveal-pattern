// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// solhint-disable-next-line no-empty-blocks
contract RockPaperScisor {
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
        REVEAL
    }

    struct RevealData {
        address player;
        Action action;
        uint256 salt;
    }

    Stage public stage = Stage.COMMIT;
    uint8 public playersCounter;

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

    function commitOf(address player) public view returns (bytes32) {
        return _commits[player];
    }

    function commitOnlyTwoPlayers(bytes32 data, uint256 salt) public payable {
        address player = msg.sender;
        uint256 amount = msg.value;

        require(amount == 5 ether, "Deposit 5 ether");
        require(_commits[player] == bytes32(""), "Already commited");
        require(stage == Stage.COMMIT, "Two players already competing");

        ++playersCounter;
        _commits[player] = keccak256(abi.encodePacked(data, salt));
        depositedETH += amount;

        if (playersCounter == 2) stage = Stage.REVEAL;
    }

    function generateSaltedHashFrom(
        RevealData memory data
    ) public pure returns (bytes32 salted) {
        return
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked(data.player, data.action)),
                    data.salt
                )
            );
    }

    function revealWinnerTwoPlayers(
        RevealData memory player1Data,
        RevealData memory player2Data
    ) public {
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

        // verify who is the winner
        BattleResult resFirstPlayer = _isFirstActionWinning(
            player1Data.action,
            player2Data.action
        );

        _revealWinner(resFirstPlayer, player1Data.player, player2Data.player);

        // add PullPayment logic
    }

    function _revealWinner(
        BattleResult resFirstPlayer,
        address player1,
        address player2
    ) internal {
        /**
         * @dev On equality, players get half of the rewards. With two players
         *      only, it means they will get back there initial deposit.
         */
        // prettier-ignore
        if (resFirstPlayer == BattleResult.EQUALITY) winner = EQUALITY_ADDR;
        else if (resFirstPlayer == BattleResult.WIN) winner = player1;
        // if not an equality or win for player1, it is a win for player2
        else winner = player2;
    }

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
}
