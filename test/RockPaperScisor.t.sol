// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/RockPaperScisor.sol";

contract RockPaperScisorTest is Test {
    RockPaperScisor public instance;

    address alice = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;
    address bob = 0xDEe2C8F3345104f6DD081657D180A9058Be7Ab05;

    bytes32 public aliceCommit;
    uint256 public constant ALICE_SALT = 0x24502340F82A423A4;
    bytes32 public aliceSaltedCommit;

    bytes32 public bobCommit;
    uint256 public constant BOB_SALT = 0x23548023FA30DC80B;
    bytes32 public bobSaltedCommit;

    function setUp() public {
        instance = new RockPaperScisor();

        vm.deal(alice, 7 ether);
        vm.deal(bob, 7 ether);

        aliceCommit = keccak256(
            abi.encodePacked(alice, RockPaperScisor.Action.ROCK)
        );
        aliceSaltedCommit = keccak256(
            abi.encodePacked(aliceCommit, ALICE_SALT)
        );

        bobCommit = keccak256(
            abi.encodePacked(bob, RockPaperScisor.Action.PAPER)
        );
        bobSaltedCommit = keccak256(abi.encodePacked(bobCommit, BOB_SALT));
    }

    function __aliceCommitsChoiceWithDeposit() private {
        vm.prank(alice);
        instance.commitOnlyTwoPlayers{value: 5 ether}(aliceCommit, ALICE_SALT);

        assert(instance.commitOf(alice) == aliceSaltedCommit);
    }

    function __bobCommitsChoiceWithDeposit() private {
        vm.prank(bob);
        instance.commitOnlyTwoPlayers{value: 5 ether}(bobCommit, BOB_SALT);

        assert(instance.commitOf(bob) == bobSaltedCommit);
    }

    /*//////////////////////////////////////////////////////////////
                                 BASIC ATTRIBUTES
    //////////////////////////////////////////////////////////////*/
    function test_commitOnlyTwoPlayers_CheckAliceAndBobCommits() public {
        __aliceCommitsChoiceWithDeposit();
        __bobCommitsChoiceWithDeposit();

        assertEq(instance.depositedETH(), 10 ether);
    }

}
