
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract OptimizedNFTCollection is ERC721, ERC721URIStorage, ERC721Burnable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    Counters.Counter private _tokenIdCounter;

    uint16 public constant MAX_SUPPLY = 10000;
    uint16 public totalMinted;
    uint64 public mintPrice = 0.01 ether;
    uint8 public maxMintsPerAddress = 10;

    bool public mintingActive = false;
    bool public revealed = false;

    bytes32 public merkleRoot;
    string private _baseTokenURI;
    string private _hiddenMetadataURI;


    mapping(address => uint8) public mintedCount;
    mapping(bytes32 => bool) public usedNonces;


    event MintingStatusChanged(bool active);
    event RevealStatusChanged(bool revealed);
    event MintPriceUpdated(uint64 newPrice);
    event BaseURIUpdated(string newBaseURI);

    constructor(
        string memory name,
        string memory symbol,
        string memory hiddenMetadataURI
    ) ERC721(name, symbol) {
        _hiddenMetadataURI = hiddenMetadataURI;
    }


    function mint(uint8 quantity) external payable nonReentrant {
        require(mintingActive, "Minting not active");
        require(quantity > 0 && quantity <= 5, "Invalid quantity");
        require(totalMinted + quantity <= MAX_SUPPLY, "Exceeds max supply");
        require(mintedCount[msg.sender] + quantity <= maxMintsPerAddress, "Exceeds max mints per address");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        mintedCount[msg.sender] += quantity;

        for (uint8 i = 0; i < quantity; i++) {
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);
            totalMinted++;
        }


        if (msg.value > mintPrice * quantity) {
            payable(msg.sender).transfer(msg.value - (mintPrice * quantity));
        }
    }

    function ownerMint(address to, uint8 quantity) external onlyOwner {
        require(quantity > 0, "Invalid quantity");
        require(totalMinted + quantity <= MAX_SUPPLY, "Exceeds max supply");

        for (uint8 i = 0; i < quantity; i++) {
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(to, tokenId);
            totalMinted++;
        }
    }


    function whitelistMint(
        uint8 quantity,
        bytes32[] calldata merkleProof,
        bytes32 nonce
    ) external payable nonReentrant {
        require(mintingActive, "Minting not active");
        require(!usedNonces[nonce], "Nonce already used");
        require(quantity > 0 && quantity <= 3, "Invalid quantity");
        require(totalMinted + quantity <= MAX_SUPPLY, "Exceeds max supply");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");


        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, nonce));
        require(_verifyMerkleProof(merkleProof, merkleRoot, leaf), "Invalid proof");

        usedNonces[nonce] = true;

        for (uint8 i = 0; i < quantity; i++) {
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);
            totalMinted++;
        }


        if (msg.value > mintPrice * quantity) {
            payable(msg.sender).transfer(msg.value - (mintPrice * quantity));
        }
    }


    function setMintingActive(bool active) external onlyOwner {
        mintingActive = active;
        emit MintingStatusChanged(active);
    }

    function setRevealed(bool _revealed) external onlyOwner {
        revealed = _revealed;
        emit RevealStatusChanged(_revealed);
    }

    function setMintPrice(uint64 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function setMaxMintsPerAddress(uint8 newMax) external onlyOwner {
        maxMintsPerAddress = newMax;
    }

    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function setHiddenMetadataURI(string calldata newHiddenURI) external onlyOwner {
        _hiddenMetadataURI = newHiddenURI;
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }


    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        if (!revealed) {
            return _hiddenMetadataURI;
        }

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, _toString(tokenId), ".json"))
            : "";
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function getRemainingSupply() external view returns (uint16) {
        return MAX_SUPPLY - totalMinted;
    }

    function getUserMintedCount(address user) external view returns (uint8) {
        return mintedCount[user];
    }


    function _verifyMerkleProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == root;
    }

    function _toString(uint256 value) internal pure returns (string memory) {
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


    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        totalMinted--;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
