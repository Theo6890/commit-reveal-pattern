// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// solhint-disable-next-line no-empty-blocks
contract RockPaperScisor {
    enum Action {
        ROCK,
        PAPER,
        SCISOR
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

}
