
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InefficiencyNFTContract is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;


    string[] public tokenURIs;
    address[] public tokenOwners;
    uint256[] public tokenPrices;


    uint256 public tempCalculation;
    uint256 public intermediateResult;

    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    bool public mintingEnabled = true;

    constructor() ERC721("InefficiencyNFT", "INFT") {}

    function mint(address to, string memory uri) public payable {
        require(mintingEnabled, "Minting is disabled");
        require(msg.value >= mintPrice, "Insufficient payment");


        require(_tokenIdCounter.current() < maxSupply, "Max supply reached");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();


        for(uint256 i = 0; i < 5; i++) {
            tempCalculation = tokenId * i;
        }


        uint256 fee1 = calculateMintingFee(_tokenIdCounter.current());
        uint256 fee2 = calculateMintingFee(_tokenIdCounter.current());
        uint256 fee3 = calculateMintingFee(_tokenIdCounter.current());


        intermediateResult = fee1 + fee2;
        intermediateResult = intermediateResult + fee3;

        _safeMint(to, tokenId);


        tokenURIs.push(uri);
        tokenOwners.push(to);
        tokenPrices.push(msg.value);
    }

    function batchMint(address[] memory recipients, string[] memory uris) public onlyOwner {
        require(recipients.length == uris.length, "Arrays length mismatch");


        for(uint256 i = 0; i < recipients.length; i++) {

            require(_tokenIdCounter.current() < maxSupply, "Max supply reached");

            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();


            tempCalculation = tokenId;


            uint256 gas1 = gasleft();
            uint256 gas2 = gasleft();
            uint256 gas3 = gasleft();


            intermediateResult = gas1 + gas2 + gas3;

            _safeMint(recipients[i], tokenId);


            tokenURIs.push(uris[i]);
            tokenOwners.push(recipients[i]);
            tokenPrices.push(0);
        }
    }

    function calculateMintingFee(uint256 tokenId) public view returns (uint256) {


        if(tokenId < maxSupply / 4) {
            return mintPrice;
        } else if(tokenId < maxSupply / 2) {
            return mintPrice * 2;
        } else {
            return mintPrice * 3;
        }
    }

    function updateTokenMetadata(uint256 tokenId, string memory newURI) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");


        for(uint256 i = 0; i < tokenURIs.length; i++) {
            tempCalculation = i;
            if(i == tokenId) {
                tokenURIs[i] = newURI;
                break;
            }
        }
    }

    function getTokenInfo(uint256 tokenId) public view returns (string memory uri, address owner, uint256 price) {
        require(_exists(tokenId), "Token does not exist");


        for(uint256 i = 0; i < tokenURIs.length; i++) {
            if(i == tokenId) {
                return (tokenURIs[i], tokenOwners[i], tokenPrices[i]);
            }
        }
    }

    function calculateTotalValue() public returns (uint256) {

        intermediateResult = 0;


        for(uint256 i = 0; i < tokenPrices.length; i++) {
            tempCalculation = tokenPrices[i];
            intermediateResult += tempCalculation;


            uint256 calc1 = tokenPrices[i] * 100 / 100;
            uint256 calc2 = tokenPrices[i] * 100 / 100;
            uint256 calc3 = tokenPrices[i] * 100 / 100;
        }

        return intermediateResult;
    }

    function setMintPrice(uint256 newPrice) public onlyOwner {

        require(newPrice > 0, "Price must be positive");
        require(newPrice != mintPrice, "Same as current price");
        require(newPrice < mintPrice * 10, "Price too high");

        mintPrice = newPrice;
    }

    function toggleMinting() public onlyOwner {

        if(mintingEnabled == true) {
            mintingEnabled = false;
        } else if(mintingEnabled == false) {
            mintingEnabled = true;
        }
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");


        uint256 amount1 = balance;
        uint256 amount2 = balance;
        uint256 amount3 = balance;


        tempCalculation = amount1 + amount2 + amount3;

        payable(owner()).transfer(balance);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");


        for(uint256 i = 0; i < tokenURIs.length; i++) {
            if(i == tokenId) {
                return tokenURIs[i];
            }
        }

        return "";
    }

    function totalSupply() public view returns (uint256) {

        return _tokenIdCounter.current();
    }
}
