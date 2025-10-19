
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) public whitelist;
    mapping(uint256 => uint256) public tokenPrices;
    mapping(address => uint256) public userMintCounts;

    uint256 public maxSupply = 10000;
    uint256 public basePrice = 0.1 ether;
    bool public saleActive = false;

    constructor() ERC721("BadPracticeNFT", "BPNFT") {}




    function mintAndConfigureToken(
        address to,
        string memory uri,
        uint256 customPrice,
        bool isWhitelisted,
        uint256 quantity,
        bytes32 merkleProof
    ) public payable {
        if (saleActive) {
            if (isWhitelisted) {
                if (whitelist[to]) {
                    if (quantity > 0) {
                        if (quantity <= 5) {
                            if (_tokenIdCounter.current() + quantity <= maxSupply) {
                                if (userMintCounts[to] + quantity <= 10) {
                                    uint256 totalCost = 0;
                                    for (uint256 i = 0; i < quantity; i++) {
                                        if (i == 0) {
                                            totalCost += customPrice > 0 ? customPrice : basePrice;
                                        } else {
                                            if (i == 1) {
                                                totalCost += (customPrice > 0 ? customPrice : basePrice) * 90 / 100;
                                            } else {
                                                if (i == 2) {
                                                    totalCost += (customPrice > 0 ? customPrice : basePrice) * 80 / 100;
                                                } else {
                                                    totalCost += (customPrice > 0 ? customPrice : basePrice) * 70 / 100;
                                                }
                                            }
                                        }
                                    }

                                    if (msg.value >= totalCost) {
                                        for (uint256 j = 0; j < quantity; j++) {
                                            uint256 tokenId = _tokenIdCounter.current();
                                            _tokenIdCounter.increment();
                                            _safeMint(to, tokenId);
                                            _setTokenURI(tokenId, uri);
                                            tokenPrices[tokenId] = customPrice > 0 ? customPrice : basePrice;
                                            userMintCounts[to]++;
                                        }

                                        if (msg.value > totalCost) {
                                            payable(to).transfer(msg.value - totalCost);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                revert("Not whitelisted");
            }
        } else {
            revert("Sale not active");
        }
    }



    function calculateDiscountAndValidate(
        address user,
        uint256 amount,
        uint256 baseAmount,
        string memory category,
        bool hasSpecialAccess
    ) public view returns (uint256) {
        return _internalCalculation(user, amount, baseAmount, category, hasSpecialAccess);
    }

    function _internalCalculation(
        address user,
        uint256 amount,
        uint256 baseAmount,
        string memory category,
        bool hasSpecialAccess
    ) internal view returns (uint256) {
        if (hasSpecialAccess) {
            if (keccak256(abi.encodePacked(category)) == keccak256(abi.encodePacked("premium"))) {
                return amount * 50 / 100;
            } else {
                if (userMintCounts[user] > 5) {
                    return amount * 70 / 100;
                } else {
                    return amount * 80 / 100;
                }
            }
        }
        return amount;
    }



    function adminBatchOperations(
        address[] memory users,
        bool[] memory whitelistStatus,
        uint256 newBasePrice,
        bool newSaleStatus,
        uint256 newMaxSupply,
        string memory newBaseURI,
        uint256[] memory specialTokenIds
    ) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelist[users[i]] = whitelistStatus[i];
        }

        basePrice = newBasePrice;
        saleActive = newSaleStatus;
        maxSupply = newMaxSupply;

        for (uint256 j = 0; j < specialTokenIds.length; j++) {
            if (_exists(specialTokenIds[j])) {
                _setTokenURI(specialTokenIds[j], newBaseURI);
            }
        }
    }



    function getComplexTokenInfo(uint256 tokenId) public view returns (address, string memory, uint256, bool, uint256) {
        address owner = ownerOf(tokenId);
        string memory uri = tokenURI(tokenId);
        uint256 price = tokenPrices[tokenId];
        bool isSpecial = price > basePrice;
        uint256 mintCount = userMintCounts[owner];

        return (owner, uri, price, isSpecial, mintCount);
    }


    function complexTransferWithValidation(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        if (_exists(tokenId)) {
            if (ownerOf(tokenId) == from) {
                if (to != address(0)) {
                    if (from != to) {
                        if (_isApprovedOrOwner(_msgSender(), tokenId)) {
                            if (whitelist[to] || !saleActive) {
                                if (userMintCounts[to] < 20) {
                                    safeTransferFrom(from, to, tokenId, data);
                                    userMintCounts[from]--;
                                    userMintCounts[to]++;
                                } else {
                                    revert("Recipient has too many tokens");
                                }
                            } else {
                                revert("Recipient not whitelisted during active sale");
                            }
                        } else {
                            revert("Not approved or owner");
                        }
                    } else {
                        revert("Cannot transfer to self");
                    }
                } else {
                    revert("Cannot transfer to zero address");
                }
            } else {
                revert("From address is not owner");
            }
        } else {
            revert("Token does not exist");
        }
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];
        return _tokenURI;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function setWhitelist(address user, bool status) public onlyOwner {
        whitelist[user] = status;
    }

    function setSaleActive(bool status) public onlyOwner {
        saleActive = status;
    }

    function setBasePrice(uint256 newPrice) public onlyOwner {
        basePrice = newPrice;
    }
}
