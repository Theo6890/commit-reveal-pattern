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
    mapping(address => bytes32) public commitOf;

    function commitOnlyTwoPlayers(bytes32 data, uint256 salt) public payable {
        require(commitOf[msg.sender] == bytes32(""), "Already commited");
        require(stage == Stage.COMMIT, "Two players already competing");
        require(msg.value == 5 ether, "Deposit 5 ether");

        ++playersCounter;
        commitOf[msg.sender] = keccak256(abi.encodePacked(data, salt));
        depositedETH += msg.value;

        if (playersCounter == 2) stage = Stage.REVEAL;
    }

    function generateSaltedHashFrom(RevealData memory data)
        public
        pure
        returns (bytes32 salted)
    {
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
            saltedHash1 == commitOf[player1Data.player],
            "P1: data mismatch"
        );
        require(
            saltedHash2 == commitOf[player2Data.player],
            "P2: data mismatch"
        );

        // verify who is the winner
        BattleResult resFirstPlayer = _isFirstActionWinning(
            player1Data.action,
            player2Data.action
        );

        // add PullPayment logic
    }

    function _isFirstActionWinning(Action a1, Action a2)
        internal
        pure
        returns (BattleResult)
    {
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
        else BattleResult.LOSS;
    }
}
