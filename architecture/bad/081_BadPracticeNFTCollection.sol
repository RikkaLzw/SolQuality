
pragma solidity ^0.8.0;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

interface IERC721Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract BadPracticeNFTCollection {

    mapping(uint256 => address) public _owners;
    mapping(address => uint256) public _balances;
    mapping(uint256 => address) public _tokenApprovals;
    mapping(address => mapping(address => bool)) public _operatorApprovals;


    string public _name = "Bad Practice NFT Collection";
    string public _symbol = "BPNFT";
    string public _baseTokenURI = "https://api.badpractice.com/metadata/";


    uint256 public _currentIndex = 1;
    address public _owner;
    uint256 public _maxSupply = 10000;
    uint256 public _mintPrice = 0.05 ether;
    bool public _paused = false;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor() {
        _owner = msg.sender;
    }


    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function balanceOf(address owner) public view returns (uint256) {

        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];

        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {

        require(_owners[tokenId] != address(0), "ERC721: invalid token ID");


        bytes memory baseURI = bytes(_baseTokenURI);
        if (baseURI.length > 0) {
            return string(abi.encodePacked(_baseTokenURI, _toString(tokenId), ".json"));
        }
        return "";
    }

    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");


        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {

        require(_owners[tokenId] != address(0), "ERC721: invalid token ID");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public {

        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {

        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {

        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {

        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }


    function mint(address to, uint256 quantity) public payable {

        require(!_paused, "Minting is paused");
        require(to != address(0), "ERC721: mint to the zero address");
        require(quantity > 0, "Quantity must be greater than 0");
        require(quantity <= 10, "Cannot mint more than 10 at once");
        require(_currentIndex + quantity <= _maxSupply, "Exceeds maximum supply");
        require(msg.value >= _mintPrice * quantity, "Insufficient payment");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _currentIndex;
            _currentIndex++;


            _balances[to]++;
            _owners[tokenId] = to;
            emit Transfer(address(0), to, tokenId);
        }
    }


    function adminMint(address to, uint256 quantity) public {

        require(msg.sender == _owner, "Only owner can admin mint");
        require(to != address(0), "ERC721: mint to the zero address");
        require(quantity > 0, "Quantity must be greater than 0");
        require(_currentIndex + quantity <= _maxSupply, "Exceeds maximum supply");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _currentIndex;
            _currentIndex++;


            _balances[to]++;
            _owners[tokenId] = to;
            emit Transfer(address(0), to, tokenId);
        }
    }


    function setPaused(bool paused) public {

        require(msg.sender == _owner, "Only owner can pause");
        _paused = paused;
    }

    function setMintPrice(uint256 newPrice) public {

        require(msg.sender == _owner, "Only owner can set price");
        _mintPrice = newPrice;
    }

    function setBaseURI(string memory newBaseURI) public {

        require(msg.sender == _owner, "Only owner can set base URI");
        _baseTokenURI = newBaseURI;
    }

    function withdraw() public {

        require(msg.sender == _owner, "Only owner can withdraw");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(_owner).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function transferOwnership(address newOwner) public {

        require(msg.sender == _owner, "Only owner can transfer ownership");
        require(newOwner != address(0), "New owner cannot be zero address");
        _owner = newOwner;
    }


    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {

        require(_owners[tokenId] != address(0), "ERC721: invalid token ID");
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");


        _approve(address(0), tokenId);


        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
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


    function totalSupply() public view returns (uint256) {
        return _currentIndex - 1;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function tokensOfOwner(address owner) public view returns (uint256[] memory) {

        require(owner != address(0), "ERC721: address zero is not a valid owner");

        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokens = new uint256[](tokenCount);
        uint256 index = 0;


        for (uint256 i = 1; i < _currentIndex && index < tokenCount; i++) {
            if (_owners[i] == owner) {
                tokens[index] = i;
                index++;
            }
        }

        return tokens;
    }


    function emergencyWithdraw() public {

        require(msg.sender == _owner, "Only owner can emergency withdraw");


        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(_owner).call{value: balance}("");
            require(success, "Emergency withdrawal failed");
        }
    }


    receive() external payable {}

    fallback() external payable {}
}
