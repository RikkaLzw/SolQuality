
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

interface IERC721Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract BadPracticeNFTCollection {
    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    string internal _name;
    string internal _symbol;
    mapping(uint256 => string) internal _tokenURIs;

    address public owner;
    uint256 public totalSupply;
    uint256 public maxSupply;
    uint256 public mintPrice;
    bool public mintingEnabled;
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public mintedCount;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor() {
        _name = "Bad Practice NFT Collection";
        _symbol = "BPNFT";
        owner = msg.sender;
        totalSupply = 0;
        maxSupply = 10000;
        mintPrice = 0.05 ether;
        mintingEnabled = true;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId ||
               interfaceId == type(IERC721Metadata).interfaceId ||
               interfaceId == type(IERC165).interfaceId;
    }

    function balanceOf(address ownerAddr) external view returns (uint256) {
        require(ownerAddr != address(0), "ERC721: address zero is not a valid owner");
        return _balances[ownerAddr];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "ERC721: invalid token ID");
        return tokenOwner;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "ERC721: URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = "https://api.badpracticenft.com/metadata/";

        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return string(abi.encodePacked(base, _toString(tokenId)));
    }

    function approve(address to, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        require(to != tokenOwner, "ERC721: approval to current owner");
        require(
            msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address ownerAddr, address operator) public view returns (bool) {
        return _operatorApprovals[ownerAddr][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    function mint(address to, uint256 tokenId) external payable {
        require(msg.sender == owner, "Only owner can mint");
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        require(totalSupply < 10000, "Max supply reached");

        _balances[to] += 1;
        _owners[tokenId] = to;
        totalSupply += 1;

        emit Transfer(address(0), to, tokenId);
    }

    function publicMint(uint256 quantity) external payable {
        require(mintingEnabled == true, "Minting is disabled");
        require(quantity > 0 && quantity <= 10, "Invalid quantity");
        require(totalSupply + quantity <= 10000, "Exceeds max supply");
        require(msg.value >= 0.05 ether * quantity, "Insufficient payment");
        require(mintedCount[msg.sender] + quantity <= 20, "Exceeds per-wallet limit");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = totalSupply + 1;
            require(!_exists(tokenId), "Token already exists");

            _balances[msg.sender] += 1;
            _owners[tokenId] = msg.sender;
            totalSupply += 1;
            mintedCount[msg.sender] += 1;

            emit Transfer(address(0), msg.sender, tokenId);
        }
    }

    function whitelistMint(uint256 quantity) external payable {
        require(whitelist[msg.sender] == true, "Not whitelisted");
        require(quantity > 0 && quantity <= 5, "Invalid quantity");
        require(totalSupply + quantity <= 10000, "Exceeds max supply");
        require(msg.value >= 0.03 ether * quantity, "Insufficient payment");
        require(mintedCount[msg.sender] + quantity <= 10, "Exceeds whitelist limit");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = totalSupply + 1;
            require(!_exists(tokenId), "Token already exists");

            _balances[msg.sender] += 1;
            _owners[tokenId] = msg.sender;
            totalSupply += 1;
            mintedCount[msg.sender] += 1;

            emit Transfer(address(0), msg.sender, tokenId);
        }
    }

    function ownerMint(address to, uint256 quantity) external {
        require(msg.sender == owner, "Only owner can mint");
        require(to != address(0), "Cannot mint to zero address");
        require(quantity > 0 && quantity <= 100, "Invalid quantity");
        require(totalSupply + quantity <= 10000, "Exceeds max supply");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = totalSupply + 1;
            require(!_exists(tokenId), "Token already exists");

            _balances[to] += 1;
            _owners[tokenId] = to;
            totalSupply += 1;

            emit Transfer(address(0), to, tokenId);
        }
    }

    function setMintingEnabled(bool enabled) external {
        require(msg.sender == owner, "Only owner can change minting status");
        mintingEnabled = enabled;
    }

    function setMintPrice(uint256 newPrice) external {
        require(msg.sender == owner, "Only owner can set price");
        mintPrice = newPrice;
    }

    function addToWhitelist(address[] calldata addresses) external {
        require(msg.sender == owner, "Only owner can manage whitelist");
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
        }
    }

    function removeFromWhitelist(address[] calldata addresses) external {
        require(msg.sender == owner, "Only owner can manage whitelist");
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
        }
    }

    function setTokenURI(uint256 tokenId, string calldata uri) external {
        require(msg.sender == owner, "Only owner can set token URI");
        require(_exists(tokenId), "Token does not exist");
        _tokenURIs[tokenId] = uri;
    }

    function withdraw() external {
        require(msg.sender == owner, "Only owner can withdraw");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner can transfer ownership");
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }

    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Caller is not owner nor approved");

        address tokenOwner = ownerOf(tokenId);

        _approve(address(0), tokenId);

        _balances[tokenOwner] -= 1;
        delete _owners[tokenId];
        delete _tokenURIs[tokenId];

        emit Transfer(tokenOwner, address(0), tokenId);
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address tokenOwner = ownerOf(tokenId);
        return (spender == tokenOwner || isApprovedForAll(tokenOwner, spender) || getApproved(tokenId) == spender);
    }

    function getApproved(uint256 tokenId) internal view returns (address) {
        return _tokenApprovals[tokenId];
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
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

    function tokensOfOwner(address ownerAddr) external view returns (uint256[] memory) {
        require(ownerAddr != address(0), "Invalid owner address");
        uint256 tokenCount = _balances[ownerAddr];
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256 index = 0;

        for (uint256 i = 1; i <= totalSupply; i++) {
            if (_owners[i] == ownerAddr) {
                tokenIds[index] = i;
                index++;
                if (index == tokenCount) {
                    break;
                }
            }
        }

        return tokenIds;
    }

    function getAllTokens() external view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](totalSupply);
        uint256 index = 0;

        for (uint256 i = 1; i <= 10000; i++) {
            if (_exists(i)) {
                tokenIds[index] = i;
                index++;
                if (index == totalSupply) {
                    break;
                }
            }
        }

        return tokenIds;
    }

    function emergencyPause() external {
        require(msg.sender == owner, "Only owner can pause");
        mintingEnabled = false;
    }

    function emergencyUnpause() external {
        require(msg.sender == owner, "Only owner can unpause");
        mintingEnabled = true;
    }

    function updateMaxSupply(uint256 newMaxSupply) external {
        require(msg.sender == owner, "Only owner can update max supply");
        require(newMaxSupply >= totalSupply, "Cannot set max supply below current supply");
        maxSupply = newMaxSupply;
    }

    receive() external payable {}

    fallback() external payable {}
}
