
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ComplexNFTCollection is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    struct TokenMetadata {
        string name;
        string description;
        uint256 rarity;
        uint256 level;
        bool isSpecial;
    }

    mapping(uint256 => TokenMetadata) public tokenMetadata;
    mapping(address => uint256[]) public userTokens;
    mapping(uint256 => uint256) public tokenPrices;
    mapping(address => bool) public whitelist;
    mapping(uint256 => address) public tokenCreators;

    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.1 ether;
    bool public saleActive = false;

    event TokenMinted(uint256 tokenId, address recipient);
    event MetadataUpdated(uint256 tokenId);
    event PriceUpdated(uint256 tokenId, uint256 price);

    constructor() ERC721("ComplexNFTCollection", "CNFT") {}





    function mintAndSetupToken(
        address recipient,
        string memory tokenName,
        string memory tokenDescription,
        uint256 rarity,
        uint256 level,
        bool isSpecial,
        uint256 price
    ) public payable nonReentrant {
        require(saleActive, "Sale not active");
        require(msg.value >= mintPrice, "Insufficient payment");
        require(_tokenIds.current() < maxSupply, "Max supply reached");
        require(bytes(tokenName).length > 0, "Name required");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();


        _safeMint(recipient, newTokenId);


        tokenMetadata[newTokenId] = TokenMetadata({
            name: tokenName,
            description: tokenDescription,
            rarity: rarity,
            level: level,
            isSpecial: isSpecial
        });


        userTokens[recipient].push(newTokenId);


        tokenPrices[newTokenId] = price;


        tokenCreators[newTokenId] = msg.sender;


        if (msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }

        emit TokenMinted(newTokenId, recipient);
        emit MetadataUpdated(newTokenId);
        emit PriceUpdated(newTokenId, price);
    }


    function batchProcessTokens(uint256[] memory tokenIds, address[] memory recipients) public onlyOwner {
        require(tokenIds.length == recipients.length, "Arrays length mismatch");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            address recipient = recipients[i];

            if (_exists(tokenId)) {
                address currentOwner = ownerOf(tokenId);

                if (currentOwner != recipient) {
                    if (tokenMetadata[tokenId].isSpecial) {
                        if (tokenMetadata[tokenId].rarity > 5) {
                            if (tokenMetadata[tokenId].level >= 10) {

                                for (uint256 j = 0; j < userTokens[currentOwner].length; j++) {
                                    if (userTokens[currentOwner][j] == tokenId) {
                                        userTokens[currentOwner][j] = userTokens[currentOwner][userTokens[currentOwner].length - 1];
                                        userTokens[currentOwner].pop();
                                        break;
                                    }
                                }

                                userTokens[recipient].push(tokenId);
                                _transfer(currentOwner, recipient, tokenId);

                                if (tokenPrices[tokenId] > 0) {
                                    tokenPrices[tokenId] = tokenPrices[tokenId] * 110 / 100;
                                }
                            } else {

                                _transfer(currentOwner, recipient, tokenId);

                                for (uint256 k = 0; k < userTokens[currentOwner].length; k++) {
                                    if (userTokens[currentOwner][k] == tokenId) {
                                        userTokens[currentOwner][k] = userTokens[currentOwner][userTokens[currentOwner].length - 1];
                                        userTokens[currentOwner].pop();
                                        break;
                                    }
                                }
                                userTokens[recipient].push(tokenId);
                            }
                        } else {

                            _transfer(currentOwner, recipient, tokenId);

                            for (uint256 l = 0; l < userTokens[currentOwner].length; l++) {
                                if (userTokens[currentOwner][l] == tokenId) {
                                    userTokens[currentOwner][l] = userTokens[currentOwner][userTokens[currentOwner].length - 1];
                                    userTokens[currentOwner].pop();
                                    break;
                                }
                            }
                            userTokens[recipient].push(tokenId);
                        }
                    } else {

                        _transfer(currentOwner, recipient, tokenId);

                        for (uint256 m = 0; m < userTokens[currentOwner].length; m++) {
                            if (userTokens[currentOwner][m] == tokenId) {
                                userTokens[currentOwner][m] = userTokens[currentOwner][userTokens[currentOwner].length - 1];
                                userTokens[currentOwner].pop();
                                break;
                            }
                        }
                        userTokens[recipient].push(tokenId);
                    }
                }
            }
        }
    }


    function getTokenInfo(uint256 tokenId) public view returns (string memory, uint256, bool) {
        require(_exists(tokenId), "Token does not exist");
        TokenMetadata memory metadata = tokenMetadata[tokenId];
        return (metadata.name, metadata.rarity, metadata.isSpecial);
    }


    function updateTokenLevel(uint256 tokenId, uint256 newLevel) public {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized");
        tokenMetadata[tokenId].level = newLevel;
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function setSaleActive(bool _active) external onlyOwner {
        saleActive = _active;
    }

    function addToWhitelist(address user) external onlyOwner {
        whitelist[user] = true;
    }

    function removeFromWhitelist(address user) external onlyOwner {
        whitelist[user] = false;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function getUserTokens(address user) external view returns (uint256[] memory) {
        return userTokens[user];
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        TokenMetadata memory metadata = tokenMetadata[tokenId];
        return string(abi.encodePacked(
            "data:application/json;base64,",
            metadata.name,
            "-",
            metadata.description
        ));
    }
}
