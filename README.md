# Curta Puzzle #8: RollApp Sequencer

`mySolution = 0x0000000000000000000000000000000030638aa1686bd3025412be656aaf8f9e`

-   To solve, we need to update `ChallengeApp::_rollAppStatesReceived` such that:
    -   `_rollAppStatesReceived(ediv, mySolution) == true`
-   Mapping must be updated via `ChallengeApp::recvRollAppData()` which can only be called by `RollApp`.
-   To do this, we can use `RollApp::execState()` to make an arbitrary call to `recvRollAppData()` with `mySolution`.

## Calling `RollApp::execState()`

This fn accepts a `bytes32 _stateHash` parameter which forms a composite key to the `stateFinalized` mapping along w/ `msg.sender`, i.e. `stateFinalized[msg.sender][_stateHash]`.

This composite key allows us to access a stored `IStateStorage.State` struct. This State struct contains all values necessary to execute the call to `ChallengeApp::recvRollAppData()`:

```javascript
struct State {
  address _submitter;    // solver (ediv)
  address _dst;          // ChallengeApp
  uint256 _blockHeight;  // whatever
  bytes _data;           // recvRollAppData calldata
}
```
Therefore, in order to get this to work, we need to first store a properly constructed State struct in the `stateFinalized` mapping.

## Setting `stateFinalized`

`stateFinalized` can be set via `RollApp::updateState()->_verifyProof()`. To do this we need to pass in our State struct along with a merkle proof. After the proof is verified, `stateFinalized` is updated within `_verifyProof()`.

For this bit to work, the provided proof must be verified against the a merkle root stored in the `stateStorage` contract. This is going to be a proof charging a minimal path through a merkle tree with nodes representing states.

So next we need to figure out how to construct our our proof and update the merkle root.

## Setting The Merkle Root

Checking out `StateStorage.sol` we see a `setMerkleProofRoot()` function that can be called (by an authorized caller) to set a merkle root. The provided `_merkleProofRoot` is stored in the `merkleProofRoot` mapping which maps addresses (tx.origin) to merkle roots.

This means we just need to set the merkle root for our solver who will be `tx.origin` in the call to `RollApp::updateState()` that ultimately verifies the merkle proof.

Some requirements:
- The length of the proof must be non-zero

## Computing The Merkle Root
The question at this point is whether we must interact with the protocol directly in some way to create the merkle root or whether we can simply compute it externally to suit our purposes.

There doesn't seem to be any requirement to do this through the protocol, so we can generate a proof that establishes our desired State struct as the leaf node of a valid merkle tree representing states belonging to our solver account.

The leaf is calculated as follows:
`bytes32 _leaf = keccak256(abi.encodePacked(sequencer.compressStateCommitments(_state)));`
