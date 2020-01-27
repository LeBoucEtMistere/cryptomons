pragma solidity ^0.5.1;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Holder.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Cryptomon.sol";

contract Market is ERC721Holder, Ownable {
    event Sold(
        address indexed _from,
        address indexed _to,
        uint256 _value,
        uint256 _tokenId
    );
    event Listed(address indexed _by, uint256 _value, uint256 _tokenId);
    event Unlisted(address indexed _by, uint256 _tokenId);
    struct SellerInfo {
        address payable seller;
        uint256 price;
        bool isSet;
    }
    uint256[] private listedTokens;
    mapping(uint256 => SellerInfo) private sellers;

    Cryptomon private CMContract;
    bool private CMCisSet = false;

    constructor() public ERC721Holder() Ownable() {}

    function setCMContract(address CMaddress) external onlyOwner() {
        CMContract = Cryptomon(CMaddress);
        CMCisSet = true;
    }

    function getCMContract() public view onlyOwner() returns (Cryptomon) {
        return CMContract;
    }
    function getListedTokens() public view returns (uint256[] memory) {
        return listedTokens;
    }
    function getTokenPrice(uint256 tokenId) public view returns (uint256) {
        require(sellers[tokenId].isSet, "Token not listed for sale");
        return sellers[tokenId].price;
    }

    function listToken(uint256 tokenId, uint256 price) public {
        require(CMCisSet, "The CMContract address has not been set properly");
        require(
            CMContract.getApproved(tokenId) == address(this) ||
                CMContract.ownerOf(tokenId) == address(this),
            "The Market is not approved for this token"
        );
        require(
            msg.sender == CMContract.ownerOf(tokenId) ||
                CMContract.ownerOf(tokenId) == address(this),
            "Trying to sell a token you do not own"
        );
        if (!sellers[tokenId].isSet) {
            listedTokens.push(tokenId);
        }
        if (CMContract.ownerOf(tokenId) == address(this)) {
            sellers[tokenId] = SellerInfo(address(0), price, true);
        } else {
            sellers[tokenId] = SellerInfo(msg.sender, price, true);
        }

        emit Listed(msg.sender, price, tokenId);
    }

    function unlistToken(uint256 tokenId) public {
        require(CMCisSet, "The CMContract address has not been set properly");
        require(
            sellers[tokenId].isSet,
            "This token is not listed on the market"
        );
        require(
            msg.sender == CMContract.ownerOf(tokenId) ||
                CMContract.ownerOf(tokenId) == address(this),
            "Trying to unlist a token you do not own"
        );

        sellers[tokenId] = SellerInfo(address(0), 0, false);
        for (uint256 i = 0; i < listedTokens.length; i++) {
            if (listedTokens[i] == tokenId) {
                _deleteListedToken(i);
            }
        }
        emit Unlisted(msg.sender, tokenId);
    }

    function _deleteListedToken(uint256 index) internal {
        require(index < listedTokens.length, "Improper index for deleting");
        listedTokens[index] = listedTokens[listedTokens.length - 1];
        delete listedTokens[listedTokens.length - 1];
        listedTokens.length--;
    }

    function buyToken(uint256 tokenId) public payable {
        require(sellers[tokenId].isSet, "This token is not listed for sale");
        require(msg.value >= sellers[tokenId].price, "money < price");
        if (sellers[tokenId].seller == address(0)) {
            CMContract.safeTransferFrom(address(this), msg.sender, tokenId);
            //owner().transfer(sellers[tokenId].price);
            emit Sold(
                address(this),
                msg.sender,
                sellers[tokenId].price,
                tokenId
            );
        } else {
            CMContract.safeTransferFrom(
                sellers[tokenId].seller,
                msg.sender,
                tokenId
            );
            sellers[tokenId].seller.transfer(sellers[tokenId].price);
            emit Sold(
                sellers[tokenId].seller,
                msg.sender,
                sellers[tokenId].price,
                tokenId
            );
        }

        sellers[tokenId] = SellerInfo(address(0), 0, false);
        for (uint256 i = 0; i < listedTokens.length; i++) {
            if (listedTokens[i] == tokenId) {
                _deleteListedToken(i);
            }
        }

    }
}
