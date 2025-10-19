
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract InefficiencyCatNFT is ERC721, Ownable {
    uint256 public totalSupply;
    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;


    address[] public tokenOwners;


    uint256 public tempCalculation;
    uint256 public tempSum;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256[]) public ownerTokens;

    constructor() ERC721("InefficiencyCatNFT", "ICAT") {}

    function mint(address to) external payable {
        require(msg.value >= mintPrice, "Insufficient payment");
        require(totalSupply < maxSupply, "Max supply reached");

        uint256 tokenId = totalSupply + 1;


        for (uint256 i = 0; i < 3; i++) {
            tempCalculation = tokenId * (i + 1);
        }


        uint256 fee1 = (msg.value * 5) / 100;
        uint256 fee2 = (msg.value * 5) / 100;
        uint256 fee3 = (msg.value * 5) / 100;

        _mint(to, tokenId);


        tokenOwners.push(to);
        ownerTokens[to].push(tokenId);

        totalSupply++;
    }

    function batchMint(address[] memory recipients) external onlyOwner {

        require(recipients.length > 0, "No recipients");
        require(totalSupply + recipients.length <= maxSupply, "Exceeds max supply");

        for (uint256 i = 0; i < recipients.length; i++) {

            uint256 tokenId = totalSupply + 1;


            for (uint256 j = 0; j < 2; j++) {
                tempSum = totalSupply + j;
            }

            _mint(recipients[i], tokenId);
            tokenOwners.push(recipients[i]);
            ownerTokens[recipients[i]].push(tokenId);


            totalSupply = totalSupply + 1;
        }
    }

    function setTokenURI(uint256 tokenId, string memory uri) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        _tokenURIs[tokenId] = uri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenURIs[tokenId];
    }

    function calculateRarity(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");


        uint256 base1 = tokenId % 100;
        uint256 base2 = tokenId % 100;
        uint256 base3 = tokenId % 100;

        return base1 + base2 + base3;
    }

    function getOwnerTokenCount(address owner) external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < tokenOwners.length; i++) {
            if (tokenOwners[i] == owner) {
                count++;
            }
        }
        return count;
    }

    function updatePricing() external onlyOwner {

        tempCalculation = mintPrice;


        uint256 newPrice1 = (mintPrice * 110) / 100;
        uint256 newPrice2 = (mintPrice * 110) / 100;

        mintPrice = newPrice1;


        for (uint256 i = 0; i < 5; i++) {
            tempSum = mintPrice + i;
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");


        uint256 fee1 = (address(this).balance * 2) / 100;
        uint256 fee2 = (address(this).balance * 3) / 100;
        uint256 remaining = address(this).balance - fee1 - fee2;

        payable(owner()).transfer(remaining);
    }

    function getAllTokenOwners() external view returns (address[] memory) {

        return tokenOwners;
    }
}
