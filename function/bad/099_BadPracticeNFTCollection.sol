
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTCollection is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    struct TokenMetadata {
        string name;
        string description;
        string imageUrl;
        uint256 rarity;
        bool isSpecial;
    }

    mapping(uint256 => TokenMetadata) public tokenMetadata;
    mapping(address => uint256) public userMintCount;
    mapping(uint256 => uint256) public tokenPrices;

    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.1 ether;
    bool public mintingActive = true;

    event TokenMinted(address indexed to, uint256 tokenId);
    event MetadataUpdated(uint256 tokenId);

    constructor() ERC721("BadPracticeNFT", "BPNFT") {}


    function mintAndConfigureTokenWithMultipleOperations(
        address recipient,
        string memory tokenName,
        string memory description,
        string memory imageUrl,
        uint256 rarity,
        bool isSpecial,
        uint256 customPrice
    ) public payable nonReentrant {
        require(mintingActive, "Minting not active");
        require(_tokenIds.current() < maxSupply, "Max supply reached");
        require(msg.value >= mintPrice, "Insufficient payment");


        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(recipient, newTokenId);


        tokenMetadata[newTokenId] = TokenMetadata({
            name: tokenName,
            description: description,
            imageUrl: imageUrl,
            rarity: rarity,
            isSpecial: isSpecial
        });


        userMintCount[recipient]++;


        tokenPrices[newTokenId] = customPrice;


        if (msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }

        emit TokenMinted(recipient, newTokenId);
        emit MetadataUpdated(newTokenId);
    }


    function getTokenComplexInfo(uint256 tokenId) public view returns (string memory, uint256, bool, address, uint256) {
        require(_exists(tokenId), "Token does not exist");
        TokenMetadata memory metadata = tokenMetadata[tokenId];
        return (
            metadata.name,
            metadata.rarity,
            metadata.isSpecial,
            ownerOf(tokenId),
            tokenPrices[tokenId]
        );
    }


    function calculateRarityBonus(uint256 rarity) public pure returns (uint256) {
        if (rarity >= 90) {
            return 1000;
        } else if (rarity >= 70) {
            return 500;
        } else if (rarity >= 50) {
            return 200;
        } else {
            return 0;
        }
    }


    function validateTokenMetadata(string memory name, string memory description) public pure returns (bool) {
        return bytes(name).length > 0 && bytes(description).length > 0;
    }


    function complexTokenOperationWithDeepNesting(uint256 tokenId, uint256 newRarity, bool shouldUpdatePrice) public {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized");

        if (tokenMetadata[tokenId].isSpecial) {
            if (newRarity > 80) {
                if (shouldUpdatePrice) {
                    if (tokenPrices[tokenId] < 1 ether) {
                        if (newRarity > 95) {
                            tokenPrices[tokenId] = 5 ether;
                        } else if (newRarity > 90) {
                            tokenPrices[tokenId] = 3 ether;
                        } else {
                            tokenPrices[tokenId] = 1 ether;
                        }
                    } else {
                        if (newRarity > 95) {
                            tokenPrices[tokenId] = tokenPrices[tokenId] * 2;
                        } else {
                            tokenPrices[tokenId] = tokenPrices[tokenId] + 1 ether;
                        }
                    }
                }
                tokenMetadata[tokenId].rarity = newRarity;
            } else {
                if (shouldUpdatePrice) {
                    if (newRarity > 50) {
                        tokenPrices[tokenId] = 0.5 ether;
                    } else {
                        tokenPrices[tokenId] = 0.1 ether;
                    }
                }
                tokenMetadata[tokenId].rarity = newRarity;
            }
        } else {
            if (newRarity > 70) {
                tokenMetadata[tokenId].isSpecial = true;
                if (shouldUpdatePrice) {
                    tokenPrices[tokenId] = 2 ether;
                }
            }
            tokenMetadata[tokenId].rarity = newRarity;
        }

        emit MetadataUpdated(tokenId);
    }


    function batchOperationsWithComplexLogic(uint256[] memory tokenIds, bool updatePrices, bool transferToOwner) public {
        require(tokenIds.length > 0, "Empty token array");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_exists(tokenIds[i])) {
                if (ownerOf(tokenIds[i]) == msg.sender || msg.sender == owner()) {
                    if (tokenMetadata[tokenIds[i]].isSpecial) {
                        if (updatePrices) {
                            if (tokenMetadata[tokenIds[i]].rarity > 90) {
                                tokenPrices[tokenIds[i]] = 10 ether;
                            } else if (tokenMetadata[tokenIds[i]].rarity > 70) {
                                tokenPrices[tokenIds[i]] = 5 ether;
                            } else {
                                tokenPrices[tokenIds[i]] = 1 ether;
                            }
                        }

                        if (transferToOwner && msg.sender != owner()) {
                            _transfer(msg.sender, owner(), tokenIds[i]);
                        }
                    } else {
                        if (updatePrices) {
                            tokenPrices[tokenIds[i]] = 0.5 ether;
                        }
                    }
                }
            }
        }
    }

    function setMintingActive(bool active) public onlyOwner {
        mintingActive = active;
    }

    function setMintPrice(uint256 price) public onlyOwner {
        mintPrice = price;
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }
}
