pragma solidity ^0.5.1;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Holder.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Cryptomon.sol";

contract Market is ERC721Holder, Ownable {
    // events to emit
    event Sold(
        address indexed _from,
        address indexed _to,
        uint256 _value,
        uint256 _tokenId
    );
    event Listed(address indexed _by, uint256 _value, uint256 _tokenId);
    event Unlisted(address indexed _by, uint256 _tokenId);

    // structs
    struct SellerInfo {
        address payable seller;
        uint256 price;
        bool isSet;
        int256 arrayIndex;
    }

    //variables
    uint256[] private listedTokens;
    mapping(uint256 => SellerInfo) private sellers;

    Cryptomon private CMContract;
    bool private CMCisSet = false;
    //cast owner address to payable
    address payable ownerP = address(uint160(owner()));

    // functions
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
        require(
            !sellers[tokenId].isSet,
            "This token is already listed on market"
        );

        listedTokens.push(tokenId);
        if (CMContract.ownerOf(tokenId) == address(this)) {
            sellers[tokenId] = SellerInfo(
                address(0),
                price,
                true,
                int256(listedTokens.length - 1)
            );
        } else {
            sellers[tokenId] = SellerInfo(
                msg.sender,
                price,
                true,
                int256(listedTokens.length - 1)
            );
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
            CMContract.getApproved(tokenId) == address(this) ||
                CMContract.ownerOf(tokenId) == address(this),
            "The Market is not approved for this token"
        );
        require(
            msg.sender == CMContract.ownerOf(tokenId) ||
                CMContract.ownerOf(tokenId) == address(this),
            "Trying to unlist a token you do not own"
        );
        require(
            sellers[tokenId].isSet,
            "This token is not yet listed on market"
        );

        // the user should unapprove the market on this token afterwards
        // as the contract cannot unapprove itself

        // clean the token from the market state
        _deleteListedToken(uint256(sellers[tokenId].arrayIndex));
        sellers[tokenId] = SellerInfo(address(0), 0, false, -1);

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

        uint256 price = sellers[tokenId].price;
        address payable seller = sellers[tokenId].seller;

        // reset state before performing transfer
        _deleteListedToken(uint256(sellers[tokenId].arrayIndex));
        sellers[tokenId] = SellerInfo(address(0), 0, false, -1);

        if (seller == address(0)) {
            // move tokens before performing transfer
            // transfering token reset its approval properly
            CMContract.safeTransferFrom(address(this), msg.sender, tokenId);
            ownerP.transfer(price);
            emit Sold(address(this), msg.sender, price, tokenId);
        } else {
            CMContract.safeTransferFrom(seller, msg.sender, tokenId);
            seller.transfer(price);
            emit Sold(seller, msg.sender, price, tokenId);
        }

    }
}
