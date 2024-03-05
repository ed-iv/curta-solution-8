// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {IPuzzle} from "curta/interfaces/IPuzzle.sol";
import {ICurta} from "curta/interfaces/ICurta.sol";
import {Merkle} from "murky/Merkle.sol";
import {ChallengeApp} from "../src/Puzzle.sol";

import {IStateStorage} from "../src/interfaces/IStateStorage.sol";
import {ISequencer} from "../src/interfaces/ISequencer.sol";
import {IRollApp} from "../src/interfaces/IRollApp.sol";

contract Solver is Script {

    ICurta curta = ICurta(0x00000000D1329c5cd5386091066d49112e590969);
    IPuzzle puzzle = IPuzzle(0x433223B5d926557A067BaA24dfE21F27C6F9FE55);
    IRollApp rollApp = IRollApp(0x32739b23BBe99900d01482Fbd3799DAf0B7Ac024);    
    ISequencer sequencer = ISequencer(0xc592A5CcC2F7839408A0b394DbDD4A756A877A77);
    IStateStorage stateStorage = IStateStorage(0x6a60D9296cBc84DC8FA4424dEdE75117712D6BE5);
    Merkle murky;

    address ediv = 0x4e763D72D21B51AD4361725Dd2B60aC9B62A680d;
    uint32 puzzleId = 8;
    uint256 solution;
    bytes32 solutionCode;

    IStateStorage.State state;
    bytes32 root;
    bytes32[] proof;

    function setUp() public {
             
    }

    function run() public {
        
        uint256 seed = puzzle.generate(ediv);
        solution = uint256(uint128(uint256(keccak256(abi.encode(seed)))));
        solutionCode = keccak256(abi.encodePacked(seed, solution));
        bytes memory _callData = sequencer.formatData(abi.encodeWithSignature("recvRollAppData(bytes32)", solutionCode));                
        state = IStateStorage.State({
            _submitter: ediv,
            _dst: address(puzzle), // puzzle8
            _blockHeight: stateStorage.getStateNonce(),
            _data: _callData
        });

        murky = new Merkle();
        
        bytes32 leaf = keccak256(abi.encodePacked(
            sequencer.compressStateCommitments(state)
        ));
        bytes32[] memory data = new bytes32[](2);
        data[0] = leaf;
        data[1] = leaf;

        // Get Root, Proof, and Verify
        root = murky.getRoot(data);
        proof = murky.getProof(data, 0); // will get proof for 0x2 value  

        vm.startBroadcast(0x4e763D72D21B51AD4361725Dd2B60aC9B62A680d);
        sequencer.setMerkleProofRoot(root);        
        bytes32 stateHash = rollApp.updateState(state, proof);
        rollApp.execState(stateHash);
        curta.solve{value: 0.02 ether}(8, solution);
        vm.stopBroadcast();
    }
}
