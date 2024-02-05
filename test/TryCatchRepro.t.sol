// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test} from "forge-std/Test.sol";
import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";

contract Foo {
    function notImplemented() external {}
}

contract Bar {
    fallback() external {}
}

contract Baz {
    function notImplemented() external returns (address) {
        return address(0x100);
    }
}

interface INotImplemented {
    function notImplemented() external returns (address);
}

contract TryCatchReproTest is Test {
    // This won't revert because foo does implement `notImplemented`.
    function testTryCatchFooRevertNotReverting() external {
        address foo = address(new Foo());
        Foo(foo).notImplemented();
    }

    // This DOES revert because the interface specifies a return that isn't
    // implemented on the contract.
    function testTryCatchFooRevertReverting() external {
        address foo = address(new Foo());
        // This errors so weirdly that vm.expectRevert() doesn't even see it.
        INotImplemented(foo).notImplemented();
    }

    // Weirdly, if we add vm.expectRevert to the exact same scenario as above,
    // the test says no revert happened.
    function testTryCatchFooRevertRevertingWithExpectRevert() external {
        address foo = address(new Foo());
        vm.expectRevert();
        INotImplemented(foo).notImplemented();
    }

    // What's REALLY a problem is that try/catch also doesn't handle the revert
    // due to the interface mismatch.
    function testTryCatchFooRevertRevertingWithTryCatch() external {
        address foo = address(new Foo());

        // This will simply revert, not be caught by the try/catch.
        try INotImplemented(foo).notImplemented() returns (address) {} catch {}
    }

    // The try/catch won't revert if we use the contract to dispatch the external
    // call rather than the interface.
    function testTryCatchFooRevertNotRevertingWithTryCatch() external {
        address foo = address(new Foo());

        // Literally we can't even compile this with a `returns` clause. Solc
        // will prevent us from doing it because it uses the contract definition
        // instead of the interface here.
        try Foo(foo).notImplemented() {
            // We hit this code path.
            assertTrue(true);
        } catch {
            assertTrue(false);
        }
    }

    // Of course we expect this to revert.
    // We are calling a function that isn't implemented on bar.
    function testTryCatchRevertNotTrying() external {
        address bar = address(new Bar());
        vm.expectRevert();
        INotImplemented(bar).notImplemented();
    }

    // This will revert because `Bar` implements the fallback function, which
    // will return empty data when `notImplemented` is called, causing the
    // abi decode to revert, despite the try/catch.
    function testTryCatchFallbackRevert() external {
        address bar = address(new Bar());

        try INotImplemented(bar).notImplemented() returns (address) {
        } catch {
        }
    }

    function testTryCatchNotRevertBytes() external {
        address foo = address(new Foo());
        address bar = address(new Bar());
        address baz = address(new Baz());

        (bool successFoo, bytes memory returnDataFoo) = foo.staticcall(abi.encodeWithSignature("notImplemented()"));
        (bool successBar, bytes memory returnDataBar) = bar.staticcall(abi.encodeWithSignature("notImplemented()"));
        (bool successBaz, bytes memory returnDataBaz) = baz.staticcall(abi.encodeWithSignature("notImplemented()"));

        assertTrue(successFoo, "foo call failed");
        assertTrue(successBar, "bar call failed");
        assertTrue(successBaz, "baz call failed");

        assertTrue(returnDataFoo.length == 0, "foo return data length");
        assertTrue(returnDataBar.length == 0, "bar return data length");
        // address is 20 bytes
        assertTrue(returnDataBaz.length == 0x20, "baz return data length");
        assertTrue(abi.decode(returnDataBaz, (address)) == address(0x100), "baz return data");
    }

    function testTryCatchBarClone() external {
        address bar = address(new Bar());
        address clone = Clones.clone(bar);

        try INotImplemented(clone).notImplemented() returns (address) {
            // We don't hit this code path.
            assertTrue(false);
        } catch {
            assertTrue(true);
        }
    }
}
