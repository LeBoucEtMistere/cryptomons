pragma solidity ^0.5.1;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/drafts/Counters.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Market.sol";

contract Cryptomon is ERC721Full, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    event Minted(bool _toMarket);

    Market private market;

    constructor(address _market)
        public
        ERC721Full("Cryptomon", "CM")
        Ownable()
    {
        market = Market(_market);
    }

    function createCryptomon(address receiver, string memory tokenURI)
        public
        onlyOwner()
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(receiver, newItemId);
        _setTokenURI(newItemId, tokenURI);

        if (receiver == address(market)) {
            emit Minted(true);
            market.listToken(newItemId, 0.001 ether);
        } else {
            emit Minted(false);
        }

        return newItemId;
    }
}
