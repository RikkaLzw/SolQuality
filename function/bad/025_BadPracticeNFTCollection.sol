
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTCollection is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) public whitelist;
    mapping(uint256 => uint256) public tokenPrices;
    mapping(address => uint256) public userMintCount;

    uint256 public maxSupply = 10000;
    uint256 public basePrice = 0.1 ether;
    bool public saleActive = false;

    event TokenMinted(address indexed to, uint256 indexed tokenId, string uri, uint256 price, bool isWhitelisted);

    constructor() ERC721("BadPracticeNFT", "BPNFT") {}



    function mintAndConfigureTokenWithMultipleOperations(
        address recipient,
        string memory tokenURI,
        uint256 customPrice,
        bool shouldAddToWhitelist,
        uint256 bulkMintCount,
        bool shouldActivateSale
    ) public payable nonReentrant {

        if (saleActive || msg.sender == owner()) {
            if (bulkMintCount > 0) {
                for (uint256 i = 0; i < bulkMintCount; i++) {
                    if (_tokenIds.current() < maxSupply) {
                        if (whitelist[recipient] || msg.value >= basePrice * bulkMintCount) {
                            _tokenIds.increment();
                            uint256 newTokenId = _tokenIds.current();
                            _mint(recipient, newTokenId);

                            if (bytes(tokenURI).length > 0) {
                                _tokenURIs[newTokenId] = tokenURI;
                            } else {
                                _tokenURIs[newTokenId] = string(abi.encodePacked("https://api.example.com/metadata/", toString(newTokenId)));
                            }

                            if (customPrice > 0) {
                                tokenPrices[newTokenId] = customPrice;
                            } else {
                                tokenPrices[newTokenId] = basePrice;
                            }

                            userMintCount[recipient]++;

                            emit TokenMinted(recipient, newTokenId, _tokenURIs[newTokenId], tokenPrices[newTokenId], whitelist[recipient]);
                        }
                    }
                }
            }


            if (shouldAddToWhitelist && msg.sender == owner()) {
                whitelist[recipient] = true;
            }


            if (shouldActivateSale && msg.sender == owner()) {
                saleActive = true;
            }


            if (customPrice > 0 && msg.sender == owner()) {
                basePrice = customPrice;
            }
        }
    }


    function processComplexTokenOperation(uint256 tokenId, address newOwner, string memory newURI) public {

        if (_exists(tokenId)) {
            if (ownerOf(tokenId) == msg.sender || msg.sender == owner()) {
                if (bytes(newURI).length > 0) {
                    _tokenURIs[tokenId] = newURI;
                    if (newOwner != address(0)) {
                        if (newOwner != ownerOf(tokenId)) {
                            _transfer(ownerOf(tokenId), newOwner, tokenId);
                            if (userMintCount[ownerOf(tokenId)] > 0) {
                                userMintCount[ownerOf(tokenId)]--;
                                userMintCount[newOwner]++;
                            }
                        }
                    }
                }
            }
        }

    }


    function updateTokenMetadataInternal(uint256 tokenId, string memory newURI) public {
        require(_exists(tokenId), "Token does not exist");
        _tokenURIs[tokenId] = newURI;
    }


    function batchUpdateTokensWithComplexLogic(
        uint256[] memory tokenIds,
        string[] memory newURIs,
        uint256[] memory newPrices,
        address[] memory newOwners,
        bool[] memory shouldTransfer,
        bool updateGlobalSettings
    ) public onlyOwner {

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_exists(tokenIds[i])) {
                if (i < newURIs.length && bytes(newURIs[i]).length > 0) {
                    _tokenURIs[tokenIds[i]] = newURIs[i];
                    if (i < newPrices.length && newPrices[i] > 0) {
                        tokenPrices[tokenIds[i]] = newPrices[i];
                        if (i < newOwners.length && newOwners[i] != address(0)) {
                            if (i < shouldTransfer.length && shouldTransfer[i]) {
                                if (newOwners[i] != ownerOf(tokenIds[i])) {
                                    _transfer(ownerOf(tokenIds[i]), newOwners[i], tokenIds[i]);
                                }
                            }
                        }
                    }
                }
            }
        }

        if (updateGlobalSettings) {
            saleActive = !saleActive;
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    function addToWhitelist(address user) public onlyOwner {
        whitelist[user] = true;
    }

    function removeFromWhitelist(address user) public onlyOwner {
        whitelist[user] = false;
    }

    function toggleSale() public onlyOwner {
        saleActive = !saleActive;
    }

    function setBasePrice(uint256 newPrice) public onlyOwner {
        basePrice = newPrice;
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }


    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
