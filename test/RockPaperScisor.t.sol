// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {RockPaperScisor} from "../src/RockPaperScisor.sol";

contract RockPaperScisorTest is Test {
    RockPaperScisor public instance;

    address public constant ALICE = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;
    address public constant BOB = 0xDEe2C8F3345104f6DD081657D180A9058Be7Ab05;

    RockPaperScisor.Action public aliceAction = RockPaperScisor.Action.ROCK;
    ///@dev encodePacked + kecccak256
    bytes32 public aliceCommit;
    uint256 public constant ALICE_SALT = 0x24502340F82A423A4;
    ///@dev kecccak256 + salt
    bytes32 public aliceSaltedCommit;
    RockPaperScisor.RevealData public revealAliceData;

    RockPaperScisor.Action public bobAction = RockPaperScisor.Action.PAPER;
    ///@dev encodePacked + kecccak256
    bytes32 public bobCommit;
    uint256 public constant BOB_SALT = 0x23548023FA30DC80B;
    ///@dev kecccak256 + salt
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
    }

    function test_Log_EQUALITY_ADDR() public {
        emit log_named_address("EQUALITY ADDRESS", instance.EQUALITY_ADDR());
    }

    function __aliceCommitsChoiceWithDeposit() private {
        vm.prank(ALICE);
        instance.commitOnlyTwoPlayers{value: 5 ether}(aliceSaltedCommit);
    }

    function __bobCommitsChoiceWithDeposit() private {
        vm.prank(BOB);
        instance.commitOnlyTwoPlayers{value: 5 ether}(bobSaltedCommit);
    }

    /*//////////////////////////////////////////////////////////////
                                 BASIC ATTRIBUTES
    //////////////////////////////////////////////////////////////*/
    function test_default_stageValue() public {
        // default value is first value of the enum Stage
        assertEq(
            uint256(instance.stage()),
            uint256(RockPaperScisor.Stage.COMMIT)
        );
    }

    function test_commitOnlyTwoPlayers_CheckSavedValuesOfAliceAndBobCommits()
        public
    {
        __aliceCommitsChoiceWithDeposit();
        assertTrue(instance.commitOf(ALICE) == aliceSaltedCommit);
        assertEq(instance.depositsOf(ALICE), 5 ether);

        // stage not changed as only one player atm
        assertEq(
            uint256(instance.stage()),
            uint256(RockPaperScisor.Stage.COMMIT)
        );

        __bobCommitsChoiceWithDeposit();
        assertTrue(instance.commitOf(BOB) == bobSaltedCommit);
        assertEq(instance.depositsOf(BOB), 5 ether);

        assertEq(instance.depositedETH(), 10 ether);

        assertEq(instance.playersLength(), 2);

        assertEq(
            uint256(instance.stage()),
            uint256(RockPaperScisor.Stage.REVEAL)
        );
    }

    // TODO: update to use on logic until requires() functions from `revealWinnerTwoPlayers`
    function test_revealWinnerTwoPlayers_VerifyDataAuthenticity() public {
        __aliceCommitsChoiceWithDeposit();
        __bobCommitsChoiceWithDeposit();

        instance.revealWinnerTwoPlayers(revealAliceData, revealBobData);

        // verify require not triggered
    }

    // TODO: add failling tests of `revealWinnerTwoPlayers` to triger both saltedHash `require()` (many different wrong params for max coverage)

    function test_revealWinnerTwoPlayers_VerifyBobWinsAndTriggeredNextStage()
        public
    {
        __aliceCommitsChoiceWithDeposit();
        __bobCommitsChoiceWithDeposit();

        instance.revealWinnerTwoPlayers(revealAliceData, revealBobData);

        assertEq(instance.winner(), BOB);
        // Bob wins everything that has been deposited
        assertEq(instance.depositsOf(BOB), instance.depositedETH());
        // Alice lost so she lost her be, resetting her deposits to 0
        assertEq(instance.depositsOf(ALICE), 0);

        // once we know the winner, the WITHDRAW_REWARDS stage is triggered
        assertEq(
            uint256(instance.stage()),
            uint256(RockPaperScisor.Stage.WITHDRAW_REWARDS)
        );
    }

    // TODO: add fixtures to cover 2 left results (LOSS, EQUALITY)
    // TODO: add tests to verify `_computeRewards` in order to ensure _deposits are not ZEROed on EQUALITY and each player can withdraw their deposits
    // TODO: add tests of  `revealWinnerTwoPlayers` to ensure _computeRewards().if(winner != address(0)) is always true
    // TODO: test gas consumption on `__resetDepositOnWinsOnly`

    function test_withdrawRewards_VerifyBobCanWithdrawReards() public {
        __aliceCommitsChoiceWithDeposit();
        __bobCommitsChoiceWithDeposit();
        instance.revealWinnerTwoPlayers(revealAliceData, revealBobData);

        uint256 oldBalance = BOB.balance;

        vm.prank(BOB); // winner
        instance.withdrawRewards();

        assertEq(BOB.balance, oldBalance + 10 ether);
    }

    function test_withdrawRewards_VerifyValuesReinitialisationAfterWinnerWithdrawal()
        public
    {
        __aliceCommitsChoiceWithDeposit();
        __bobCommitsChoiceWithDeposit();
        instance.revealWinnerTwoPlayers(revealAliceData, revealBobData);

        vm.prank(BOB); // winner
        instance.withdrawRewards();

        // ------ reset verification ------ //
        assertEq(
            uint256(instance.stage()),
            uint256(RockPaperScisor.Stage.COMMIT)
        );
        assertEq(instance.depositedETH(), 0 ether);
        assertTrue(instance.winner() == address(0));
        // commits
        assertTrue(instance.commitOf(ALICE) == bytes32(""));
        assertTrue(instance.commitOf(BOB) == bytes32(""));
        // deposits
        assertEq(instance.depositsOf(BOB), 0);
        assertEq(instance.depositsOf(ALICE), 0);
        // registered players
        assertTrue(instance.playersLength() == 0);
    }

    // TODO: add tests of values reinitialisation when there is an EQUALITY
}
