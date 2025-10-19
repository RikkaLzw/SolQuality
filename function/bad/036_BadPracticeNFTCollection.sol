
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) public whitelist;
    mapping(uint256 => uint256) public tokenPrices;
    mapping(address => uint256) public userMintCounts;

    uint256 public maxSupply = 10000;
    uint256 public publicSalePrice = 0.1 ether;
    bool public saleActive = false;
    bool public whitelistSaleActive = false;

    constructor() ERC721("BadPracticeNFT", "BPNFT") {}





    function mintAndSetupTokenWithMultipleOperations(
        address to,
        string memory uri,
        uint256 price,
        bool isWhitelistMint,
        uint256 quantity,
        bytes32 merkleProof
    ) public payable {

        if (isWhitelistMint) {
            if (whitelistSaleActive) {
                if (whitelist[to]) {
                    if (quantity > 0 && quantity <= 5) {
                        if (userMintCounts[to] + quantity <= 5) {
                            if (_tokenIds.current() + quantity <= maxSupply) {
                                if (msg.value >= price * quantity) {
                                    for (uint256 i = 0; i < quantity; i++) {
                                        _tokenIds.increment();
                                        uint256 newTokenId = _tokenIds.current();
                                        _mint(to, newTokenId);
                                        _setTokenURI(newTokenId, uri);
                                        tokenPrices[newTokenId] = price;
                                        userMintCounts[to]++;


                                        if (msg.value > price * quantity) {
                                            payable(msg.sender).transfer(msg.value - (price * quantity));
                                        }
                                    }


                                    if (userMintCounts[to] >= 5) {
                                        whitelist[to] = false;
                                    }
                                } else {
                                    revert("Insufficient payment");
                                }
                            } else {
                                revert("Exceeds max supply");
                            }
                        } else {
                            revert("Exceeds mint limit");
                        }
                    } else {
                        revert("Invalid quantity");
                    }
                } else {
                    revert("Not whitelisted");
                }
            } else {
                revert("Whitelist sale not active");
            }
        } else {
            if (saleActive) {
                if (quantity > 0 && quantity <= 10) {
                    if (_tokenIds.current() + quantity <= maxSupply) {
                        if (msg.value >= publicSalePrice * quantity) {
                            for (uint256 i = 0; i < quantity; i++) {
                                _tokenIds.increment();
                                uint256 newTokenId = _tokenIds.current();
                                _mint(to, newTokenId);
                                _setTokenURI(newTokenId, uri);
                                tokenPrices[newTokenId] = publicSalePrice;
                                userMintCounts[to]++;


                                if (msg.value > publicSalePrice * quantity) {
                                    payable(msg.sender).transfer(msg.value - (publicSalePrice * quantity));
                                }
                            }
                        } else {
                            revert("Insufficient payment");
                        }
                    } else {
                        revert("Exceeds max supply");
                    }
                } else {
                    revert("Invalid quantity");
                }
            } else {
                revert("Sale not active");
            }
        }
    }



    function updateTokenMetadataAndPricing(
        uint256 tokenId,
        string memory newURI,
        uint256 newPrice,
        address newOwner,
        bool transferOwnership,
        string memory additionalMetadata
    ) public {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || msg.sender == owner(), "Not authorized");

        _setTokenURI(tokenId, newURI);
        tokenPrices[tokenId] = newPrice;

        if (transferOwnership && newOwner != address(0)) {
            _transfer(ownerOf(tokenId), newOwner, tokenId);
        }
    }



    function getTokenInfoAndUserStats(uint256 tokenId, address user) public view returns (string memory, uint256, uint256, bool, uint256) {
        require(_exists(tokenId), "Token does not exist");


        string memory uri = tokenURI(tokenId);
        uint256 price = tokenPrices[tokenId];


        uint256 userMintCount = userMintCounts[user];
        bool isUserWhitelisted = whitelist[user];


        uint256 userTokenCount = balanceOf(user);

        return (uri, price, userMintCount, isUserWhitelisted, userTokenCount);
    }


    function _setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }



    function adminOperations(
        bool setSaleActive,
        bool setWhitelistSaleActive,
        uint256 newPublicPrice,
        address[] memory whitelistAddresses,
        bool addToWhitelist,
        uint256 newMaxSupply
    ) public onlyOwner {
        if (setSaleActive != saleActive) {
            saleActive = setSaleActive;
        }

        if (setWhitelistSaleActive != whitelistSaleActive) {
            whitelistSaleActive = setWhitelistSaleActive;
        }

        if (newPublicPrice != publicSalePrice && newPublicPrice > 0) {
            publicSalePrice = newPublicPrice;
        }

        if (whitelistAddresses.length > 0) {
            for (uint256 i = 0; i < whitelistAddresses.length; i++) {
                if (whitelistAddresses[i] != address(0)) {
                    if (addToWhitelist) {
                        if (!whitelist[whitelistAddresses[i]]) {
                            whitelist[whitelistAddresses[i]] = true;
                        }
                    } else {
                        if (whitelist[whitelistAddresses[i]]) {
                            whitelist[whitelistAddresses[i]] = false;
                        }
                    }
                }
            }
        }

        if (newMaxSupply != maxSupply && newMaxSupply >= _tokenIds.current()) {
            maxSupply = newMaxSupply;
        }
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }
}
