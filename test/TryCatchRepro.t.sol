// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test} from "forge-std/Test.sol";

contract Foo {}

interface INotImplemented {
    function notImplemented() external returns (address);
}

contract TryCatchReproTest is Test {

    // Of course we expect this to revert.
    // We are calling a function that isn't implemented.
    function testTryCatchRevertNotTrying() external {
        address foo = address(new Foo());
        vm.expectRevert();
        INotImplemented(foo).notImplemented();
    }

    function testTryCatchRevert() external {
        address foo = address(new Foo());

        try INotImplemented(foo).notImplemented() returns (address result) {
            require(result == address(0), "result should be 0");
        } catch {
        }
    }

}