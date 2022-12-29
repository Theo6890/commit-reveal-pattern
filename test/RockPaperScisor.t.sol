// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {RockPaperScisor} from "../src/RockPaperScisor.sol";

contract RockPaperScisorTest is Test {
    RockPaperScisor public instance;

    address public constant ALICE = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;
    address public constant BOB = 0xDEe2C8F3345104f6DD081657D180A9058Be7Ab05;

    RockPaperScisor.Action public aliceAction = RockPaperScisor.Action.ROCK;
    bytes32 public aliceCommit;
    uint256 public constant ALICE_SALT = 0x24502340F82A423A4;
    bytes32 public aliceSaltedCommit;
    RockPaperScisor.RevealData public revealAliceData;

    RockPaperScisor.Action public bobAction = RockPaperScisor.Action.PAPER;
    bytes32 public bobCommit;
    uint256 public constant BOB_SALT = 0x23548023FA30DC80B;
    bytes32 public bobSaltedCommit;
    RockPaperScisor.RevealData public revealBobData;

    function setUp() public {
        instance = new RockPaperScisor();

        vm.deal(ALICE, 7 ether);
        vm.deal(BOB, 7 ether);

        aliceCommit = keccak256(abi.encodePacked(ALICE, aliceAction));
        aliceSaltedCommit = keccak256(
            abi.encodePacked(aliceCommit, ALICE_SALT)
        );
        revealAliceData = RockPaperScisor.RevealData(
            ALICE,
            aliceAction,
            ALICE_SALT
        );

        bobCommit = keccak256(abi.encodePacked(BOB, bobAction));
        bobSaltedCommit = keccak256(abi.encodePacked(bobCommit, BOB_SALT));
        revealBobData = RockPaperScisor.RevealData(BOB, bobAction, BOB_SALT);

        emit log_named_address("EQUALITY ADDRESS", instance.EQUALITY_ADDR());
    }

    function __aliceCommitsChoiceWithDeposit() private {
        vm.prank(ALICE);
        instance.commitOnlyTwoPlayers{value: 5 ether}(aliceCommit, ALICE_SALT);

        assert(instance.commitOf(ALICE) == aliceSaltedCommit);
    }

    function __bobCommitsChoiceWithDeposit() private {
        vm.prank(BOB);
        instance.commitOnlyTwoPlayers{value: 5 ether}(bobCommit, BOB_SALT);

        assert(instance.commitOf(BOB) == bobSaltedCommit);
    }

    /*//////////////////////////////////////////////////////////////
                                 BASIC ATTRIBUTES
    //////////////////////////////////////////////////////////////*/
    function test_commitOnlyTwoPlayers_CheckAliceAndBobCommits() public {
        __aliceCommitsChoiceWithDeposit();
        __bobCommitsChoiceWithDeposit();

        assertEq(instance.depositedETH(), 10 ether);
    }

    function test_revealWinnerTwoPlayers_VerifyDataAuthenticity() public {
        __aliceCommitsChoiceWithDeposit();
        __bobCommitsChoiceWithDeposit();

        instance.revealWinnerTwoPlayers(revealAliceData, revealBobData);
    }
}
