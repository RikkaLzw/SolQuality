
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256) public userMintCount;
    mapping(uint256 => bool) public tokenExists;
    mapping(address => bool) public whitelist;

    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    bool public mintingEnabled = false;

    constructor() ERC721("BadPracticeNFT", "BPNFT") {}


    function complexMintAndManage(
        address to,
        string memory uri,
        uint256 quantity,
        bool updatePrice,
        uint256 newPrice,
        bool toggleMinting,
        address whitelistUser
    ) public payable {

        if (mintingEnabled) {
            if (quantity > 0) {
                if (to != address(0)) {
                    if (_tokenIdCounter.current() + quantity <= maxSupply) {
                        if (msg.value >= mintPrice * quantity || msg.sender == owner()) {
                            for (uint256 i = 0; i < quantity; i++) {
                                if (_tokenIdCounter.current() < maxSupply) {
                                    uint256 tokenId = _tokenIdCounter.current();
                                    _tokenIdCounter.increment();
                                    _safeMint(to, tokenId);
                                    _setTokenURI(tokenId, uri);
                                    tokenExists[tokenId] = true;
                                    userMintCount[to]++;
                                }
                            }
                        }
                    }
                }
            }
        }

        if (updatePrice && msg.sender == owner()) {
            if (newPrice > 0) {
                mintPrice = newPrice;
            }
        }

        if (toggleMinting && msg.sender == owner()) {
            mintingEnabled = !mintingEnabled;
        }

        if (whitelistUser != address(0) && msg.sender == owner()) {
            whitelist[whitelistUser] = !whitelist[whitelistUser];
        }
    }


    function getUserInfo(address user) public view {
        userMintCount[user];
        whitelist[user];
        balanceOf(user);
    }


    function _setTokenURI(uint256 tokenId, string memory uri) public {
        require(_exists(tokenId), "Token does not exist");
        _tokenURIs[tokenId] = uri;
    }


    function adminOperations(
        uint256 newMaxSupply,
        address newOwner,
        bool enableMinting
    ) public onlyOwner {
        if (newMaxSupply > 0 && newMaxSupply != maxSupply) {
            maxSupply = newMaxSupply;
        }

        if (newOwner != address(0) && newOwner != owner()) {
            _transferOwnership(newOwner);
        }

        mintingEnabled = enableMinting;
    }


    function batchOperations(
        address[] memory recipients,
        uint256[] memory tokenIds,
        string[] memory uris,
        bool[] memory whitelistStatus
    ) public onlyOwner {
        if (recipients.length > 0) {
            if (tokenIds.length == recipients.length) {
                if (uris.length == recipients.length) {
                    if (whitelistStatus.length == recipients.length) {
                        for (uint256 i = 0; i < recipients.length; i++) {
                            if (recipients[i] != address(0)) {
                                if (tokenIds[i] < maxSupply) {
                                    if (!_exists(tokenIds[i])) {
                                        _safeMint(recipients[i], tokenIds[i]);
                                        _setTokenURI(tokenIds[i], uris[i]);
                                        tokenExists[tokenIds[i]] = true;
                                        userMintCount[recipients[i]]++;

                                        if (whitelistStatus[i]) {
                                            whitelist[recipients[i]] = true;
                                        } else {
                                            whitelist[recipients[i]] = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenURIs[tokenId];
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }
}
