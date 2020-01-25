pragma solidity^0.5.1;

import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol';
import "openzeppelin-solidity/contracts/drafts/Counters.sol";
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract Cryptomon is ERC721Full, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() ERC721Full("Cryptomon", "CM") Ownable() public {}

  function createCryptomon(address receiver, string memory tokenURI) public onlyOwner() returns (uint) {
    _tokenIds.increment();

    uint256 newItemId = _tokenIds.current();
    _safeMint(receiver, newItemId);
    _setTokenURI(newItemId, tokenURI);

    return newItemId;
  }
}