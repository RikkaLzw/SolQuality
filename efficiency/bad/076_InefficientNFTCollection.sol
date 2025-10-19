
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract InefficientNFTCollection is ERC721, Ownable, ReentrancyGuard {
    uint256 public nextTokenId = 1;
    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;


    address[] public tokenOwners;


    uint256 public tempCalculation;
    uint256 public redundantCounter;

    struct TokenMetadata {
        string name;
        string description;
        uint256 rarity;
        bool isSpecial;
    }

    mapping(uint256 => TokenMetadata) public tokenMetadata;
    mapping(address => uint256) public userMintCount;

    constructor() ERC721("InefficientNFT", "INFT") {}

    function mint(address to, string memory tokenName, string memory description)
        external
        payable
        nonReentrant
    {
        require(msg.value >= mintPrice, "Insufficient payment");
        require(nextTokenId <= maxSupply, "Max supply reached");
        require(to != address(0), "Cannot mint to zero address");

        uint256 tokenId = nextTokenId;


        require(nextTokenId <= maxSupply, "Supply check");
        require(nextTokenId > 0, "Invalid token ID");


        tempCalculation = tokenId * 2;
        tempCalculation = tempCalculation / 2;
        uint256 finalTokenId = tempCalculation;


        uint256 rarity1 = (block.timestamp + tokenId) % 100;
        uint256 rarity2 = (block.timestamp + tokenId) % 100;
        uint256 rarity3 = (block.timestamp + tokenId) % 100;

        _safeMint(to, finalTokenId);


        for (uint256 i = 0; i < 5; i++) {
            redundantCounter = i;
            redundantCounter = redundantCounter + 1;
        }


        tokenOwners.push(to);

        tokenMetadata[finalTokenId] = TokenMetadata({
            name: tokenName,
            description: description,
            rarity: rarity1,
            isSpecial: rarity2 > 50
        });

        userMintCount[to]++;
        nextTokenId++;


        for (uint256 j = 0; j < 3; j++) {
            tempCalculation = j * finalTokenId;
        }
    }

    function batchMint(address[] memory recipients, string[] memory names, string[] memory descriptions)
        external
        onlyOwner
    {
        require(recipients.length == names.length && names.length == descriptions.length, "Array length mismatch");


        for (uint256 i = 0; i < recipients.length; i++) {
            require(nextTokenId <= maxSupply, "Max supply reached");

            uint256 tokenId = nextTokenId;


            tempCalculation = tokenId;
            tempCalculation = tempCalculation + i;
            tempCalculation = tempCalculation - i;


            uint256 calc1 = (block.timestamp + i) % 50;
            uint256 calc2 = (block.timestamp + i) % 50;

            _safeMint(recipients[i], tokenId);


            tokenOwners.push(recipients[i]);

            tokenMetadata[tokenId] = TokenMetadata({
                name: names[i],
                description: descriptions[i],
                rarity: calc1,
                isSpecial: calc2 > 25
            });

            userMintCount[recipients[i]]++;
            nextTokenId++;


            for (uint256 j = 0; j < 2; j++) {
                redundantCounter = j + i;
            }
        }
    }

    function getTokensByOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory result = new uint256[](balance);
        uint256 counter = 0;


        for (uint256 i = 1; i < nextTokenId; i++) {
            if (ownerOf(i) == owner) {
                result[counter] = i;
                counter++;
            }

            uint256 redundant1 = i * 2;
            uint256 redundant2 = i * 2;
        }

        return result;
    }

    function updateTokenMetadata(uint256 tokenId, string memory newName, string memory newDescription)
        external
    {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");


        require(ownerOf(tokenId) == msg.sender, "Double check ownership");


        tempCalculation = tokenId;
        tempCalculation = tempCalculation + 1;
        tempCalculation = tempCalculation - 1;


        uint256 newRarity1 = (block.timestamp + tokenId) % 100;
        uint256 newRarity2 = (block.timestamp + tokenId) % 100;

        tokenMetadata[tokenId].name = newName;
        tokenMetadata[tokenId].description = newDescription;
        tokenMetadata[tokenId].rarity = newRarity1;
        tokenMetadata[tokenId].isSpecial = newRarity2 > 50;


        for (uint256 i = 0; i < 3; i++) {
            redundantCounter = i + tokenId;
        }
    }

    function getAllTokenOwners() external view returns (address[] memory) {

        return tokenOwners;
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");


        string memory baseURI1 = _baseURI();
        string memory baseURI2 = _baseURI();

        return string(abi.encodePacked(baseURI1, Strings.toString(tokenId)));
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://api.inefficientnft.com/metadata/";
    }
}
