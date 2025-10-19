
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFTCollection is ERC721, Ownable {
    uint256 public a;
        uint256 public b = 1000;
    uint256 public c = 0.01 ether;
  bool public d = false;

    mapping(uint256 => string) private e;
        mapping(address => uint256) public f;

    string private g = "";

    constructor() ERC721("MyNFT", "MNFT") {
a = 1;
    }


    function set_base_uri(string memory _uri) public onlyOwner {
        g = _uri;
    }

    function toggle_sale() public onlyOwner { d = !d; }


    function mint_nft(uint256 temp1) public payable {
        require(d == true, "Sale not active"); require(temp1 > 0 && temp1 <= 10, "Invalid amount");
        require(a + temp1 <= b, "Exceeds max supply");
        require(msg.value >= c * temp1, "Insufficient payment");

        uint256 x = f[msg.sender];
        require(x + temp1 <= 5, "Max 5 per wallet");

        for(uint256 i = 0; i < temp1; i++) {
            _safeMint(msg.sender, a); f[msg.sender]++;
            a++;
        }
    }


    function owner_mint(address to, uint256 amount) public onlyOwner {
    require(a + amount <= b, "Exceeds supply");
        for(uint256 j = 0; j < amount; j++) {
            _safeMint(to, a);
                a++;
        }
    }

    function set_price(uint256 new_price) public onlyOwner { c = new_price; }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        string memory temp2 = e[tokenId];
        if(bytes(temp2).length > 0) {
            return temp2;
        }

        return string(abi.encodePacked(g, Strings.toString(tokenId), ".json"));
    }


    function withdraw_funds() public onlyOwner {
        uint256 balance = address(this).balance; payable(owner()).transfer(balance);
    }

        function set_token_uri(uint256 tokenId, string memory uri) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
    e[tokenId] = uri;
        }

    function get_total_supply() public view returns (uint256) {
        return a - 1;
    }


    function batch_transfer(address[] memory recipients, uint256[] memory tokenIds) public {
        require(recipients.length == tokenIds.length, "Arrays length mismatch"); uint256 len = recipients.length;
        for(uint256 k = 0; k < len; k++) { require(ownerOf(tokenIds[k]) == msg.sender, "Not owner"); transferFrom(msg.sender, recipients[k], tokenIds[k]); }
    }
}
