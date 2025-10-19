
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PremiumNFTCollection is ERC721, ERC721URIStorage, ERC721Burnable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINT_PER_TX = 10;
    uint256 public mintPrice = 0.01 ether;

    bool public mintingActive = false;
    bool public whitelistActive = false;

    bytes32 private _merkleRoot;

    mapping(address => uint8) private _whitelistMinted;
    mapping(address => bool) private _blacklisted;
    mapping(uint256 => bytes32) private _tokenHashes;

    event MintPriceUpdated(uint256 newPrice);
    event MintingStatusChanged(bool active);
    event WhitelistStatusChanged(bool active);
    event MerkleRootUpdated(bytes32 newRoot);
    event TokenMinted(address indexed to, uint256 indexed tokenId, bytes32 tokenHash);

    constructor(
        string memory name,
        string memory symbol,
        bytes32 merkleRoot
    ) ERC721(name, symbol) {
        _merkleRoot = merkleRoot;
    }

    modifier notBlacklisted(address account) {
        require(!_blacklisted[account], "Address is blacklisted");
        _;
    }

    modifier validMintAmount(uint8 amount) {
        require(amount > 0 && amount <= MAX_MINT_PER_TX, "Invalid mint amount");
        require(_tokenIdCounter.current() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _;
    }

    function mint(uint8 amount)
        external
        payable
        nonReentrant
        notBlacklisted(msg.sender)
        validMintAmount(amount)
    {
        require(mintingActive, "Minting not active");
        require(msg.value >= mintPrice * amount, "Insufficient payment");

        _mintTokens(msg.sender, amount);
    }

    function whitelistMint(
        uint8 amount,
        uint8 maxAmount,
        bytes32[] calldata merkleProof
    )
        external
        payable
        nonReentrant
        notBlacklisted(msg.sender)
        validMintAmount(amount)
    {
        require(whitelistActive, "Whitelist minting not active");
        require(_whitelistMinted[msg.sender] + amount <= maxAmount, "Exceeds whitelist allocation");
        require(msg.value >= mintPrice * amount, "Insufficient payment");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, maxAmount));
        require(_verifyMerkleProof(merkleProof, _merkleRoot, leaf), "Invalid merkle proof");

        _whitelistMinted[msg.sender] += amount;
        _mintTokens(msg.sender, amount);
    }

    function ownerMint(address to, uint8 amount)
        external
        onlyOwner
        validMintAmount(amount)
    {
        _mintTokens(to, amount);
    }

    function _mintTokens(address to, uint8 amount) private {
        for (uint8 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            bytes32 tokenHash = keccak256(abi.encodePacked(
                block.timestamp,
                block.difficulty,
                tokenId,
                to
            ));

            _tokenHashes[tokenId] = tokenHash;
            _safeMint(to, tokenId);

            emit TokenMinted(to, tokenId, tokenHash);
        }
    }

    function setTokenURI(uint256 tokenId, string memory uri) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        _setTokenURI(tokenId, uri);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function setMintingActive(bool active) external onlyOwner {
        mintingActive = active;
        emit MintingStatusChanged(active);
    }

    function setWhitelistActive(bool active) external onlyOwner {
        whitelistActive = active;
        emit WhitelistStatusChanged(active);
    }

    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        _merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    function setBlacklist(address account, bool blacklisted) external onlyOwner {
        _blacklisted[account] = blacklisted;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function getTokenHash(uint256 tokenId) external view returns (bytes32) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenHashes[tokenId];
    }

    function getWhitelistMinted(address account) external view returns (uint8) {
        return _whitelistMinted[account];
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }

    function _verifyMerkleProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) private pure returns (bool) {
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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        require(!_blacklisted[from] && !_blacklisted[to], "Blacklisted address");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        delete _tokenHashes[tokenId];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
