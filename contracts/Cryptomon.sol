pragma solidity ^0.5.1;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/drafts/Counters.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Market.sol";

contract Cryptomon is ERC721Full, Ownable {
    // struct
    struct BreedData {
        uint256 with;
        uint256 startTime;
        uint256 endTime;
        bool isSet;
    }

    //events
    event Breeding(
        uint256 indexed parent1,
        uint256 indexed parent2,
        uint256 endTime
    );
    event Interrupted(
        uint256 indexed parent1,
        uint256 indexed parent2,
        address by
    );
    event Hatched(
        uint256 indexed tokenId,
        uint256 indexed parent1,
        uint256 indexed parent2
    );
    event Fighted(
        address attacker,
        address defender,
        uint256 attacker_token,
        uint256 defender_token,
        bool win
    );

    event Minted(bool _toMarket);

    //variables
    uint256[] private breedingTokens;
    mapping(uint256 => BreedData) private breeders;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    Market private market;

    //functions
    constructor(address _market)
        public
        ERC721Full("Cryptomon", "CM")
        Ownable()
    {
        market = Market(_market);
    }

    function createCryptomon(
        address receiver,
        string memory tokenURI,
        uint256 price
    ) public onlyOwner() returns (uint256) {
        // price is only used when minting to the market to set initial price
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(receiver, newItemId);
        _setTokenURI(newItemId, tokenURI);

        if (receiver == address(market)) {
            emit Minted(true);
            market.listToken(newItemId, price);
        } else {
            emit Minted(false);
        }

        return newItemId;
    }

    // function sellOnMarket(uint256 tokenId, uint256 price) public {
    //     require(
    //         msg.sender == ownerOf(tokenId),
    //         "you cannot sell a token you do not own"
    //     );
    //     approve(address(market), tokenId);
    //     market.listToken(tokenId, price);
    // }

    function getBreedingTokens() public view returns (uint256[] memory) {
        return breedingTokens;
    }

    function hasHatched(uint256 cm1) public view returns (bool) {
        require(breeders[cm1].isSet, "This cryptomon did not breed");
        return now > breeders[cm1].endTime;
    }

    function hasHatched(uint256 cm1, uint256 cm2) public view returns (bool) {
        require(breeders[cm1].isSet, "This cryptomon did not breed");
        require(breeders[cm2].isSet, "This cryptomon did not breed");
        require(breeders[cm1].with == cm2, "These 2 are not breeding together");
        require(breeders[cm2].with == cm1, "These 2 are not breeding together");
        return now > breeders[cm1].endTime;
    }

    function isBreeding(uint256 tokenId) public view returns (bool) {
        return breeders[tokenId].isSet;
    }

    function breed(uint256 cm1, uint256 cm2) public {
        require(
            ownerOf(cm1) == msg.sender,
            "Can only breed cryptomons you own"
        );
        require(
            ownerOf(cm2) == msg.sender,
            "Can only breed cryptomons you own"
        );

        require(!breeders[cm1].isSet, "One cryptomon is already breeding");
        require(!breeders[cm2].isSet, "One cryptomon is already breeding");

        breedingTokens.push(cm1);
        breedingTokens.push(cm2);
        uint256 end = now + 1 minutes + 30;
        breeders[cm1] = BreedData(cm2, now, end, true);
        breeders[cm2] = BreedData(cm1, now, end, true);

        emit Breeding(cm1, cm2, end);
    }

    function interruptBreeding(uint256 tokenId) public {
        require(breeders[tokenId].isSet, "This token is not breeding");
        require(
            !hasHatched(tokenId, breeders[tokenId].with),
            "This token has already finished breeding"
        );

        emit Interrupted(tokenId, breeders[tokenId].with, msg.sender);

        _clearBreeding(tokenId, breeders[tokenId].with);

    }

    function _deleteBreedingToken(uint256 index) internal {
        require(index < breedingTokens.length, "Improper index for deleting");
        breedingTokens[index] = breedingTokens[breedingTokens.length - 1];
        delete breedingTokens[breedingTokens.length - 1];
        breedingTokens.length--;
    }

    function _clearBreeding(uint256 cm1, uint256 cm2) internal {
        breeders[cm1] = BreedData(0, 0, 0, false);
        breeders[cm2] = BreedData(0, 0, 0, false);
        for (uint256 i = 0; i < breedingTokens.length; i++) {
            if (breedingTokens[i] == cm1) {
                _deleteBreedingToken(i);
            }
        }
        for (uint256 i = 0; i < breedingTokens.length; i++) {
            if (breedingTokens[i] == cm2) {
                _deleteBreedingToken(i);
            }
        }
    }

    function hatch(uint256 cm1, uint256 cm2) public {
        require(
            ownerOf(cm1) == msg.sender,
            "Can only hatch cryptomons you own"
        );
        require(
            ownerOf(cm2) == msg.sender,
            "Can only hatch cryptomons you own"
        );
        // all important verifications are done in hasHatched to avoid redoing it
        require(hasHatched(cm1, cm2), "This cryptomon is not hatched yet");

        string memory newTokenUri;
        uint256 random = uint256(blockhash(block.number - 1));
        if (random % 2 == 0) {
            newTokenUri = this.tokenURI(cm1);
        } else {
            newTokenUri = this.tokenURI(cm2);
        }
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, newTokenUri);

        _clearBreeding(cm1, cm2);

        emit Hatched(newItemId, cm1, cm2);

    }

    function fight(uint256 attacker, uint256 defender) public {
        require(
            ownerOf(attacker) == msg.sender,
            "Can only attack with a cryptomon you own"
        );
        require(
            ownerOf(defender) != msg.sender,
            "Can only attack someone's else cryptomon"
        );

        uint256 random = uint256(blockhash(block.number - 1));
        if (random % 2 == 0) {
            // won
            if (isBreeding(defender)) {
                interruptBreeding(defender);
            }
            emit Fighted(
                msg.sender,
                ownerOf(defender),
                attacker,
                defender,
                true
            );
        } else {
            // lost
            emit Fighted(
                msg.sender,
                ownerOf(defender),
                attacker,
                defender,
                false
            );
        }

    }
}
