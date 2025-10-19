
pragma solidity ^0.8.0;

contract BadPracticeNFTCollection {
    string internal _name;
    string internal _symbol;
    uint256 internal _currentTokenId;

    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;
    mapping(uint256 => string) internal _tokenURIs;

    address internal _contractOwner;
    bool internal _paused;
    uint256 internal _maxSupply;
    uint256 internal _mintPrice;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _contractOwner = msg.sender;
        _paused = false;
        _maxSupply = 10000;
        _mintPrice = 0.05 ether;
        _currentTokenId = 1;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 ||
               interfaceId == 0x80ac58cd ||
               interfaceId == 0x5b5e139f;
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(msg.sender == owner || _operatorApprovals[owner][msg.sender],
                "ERC721: approve caller is not owner nor approved for all");

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        require(_owners[tokenId] != address(0), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        require(from != address(0), "ERC721: transfer from the zero address");
        require(to != address(0), "ERC721: transfer to the zero address");
        require(_owners[tokenId] == from, "ERC721: transfer from incorrect owner");

        _tokenApprovals[tokenId] = address(0);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        require(from != address(0), "ERC721: transfer from the zero address");
        require(to != address(0), "ERC721: transfer to the zero address");
        require(_owners[tokenId] == from, "ERC721: transfer from incorrect owner");

        _tokenApprovals[tokenId] = address(0);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "") returns (bytes4 retval) {
                require(retval == IERC721Receiver.onERC721Received.selector, "ERC721: transfer to non ERC721Receiver implementer");
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        require(from != address(0), "ERC721: transfer from the zero address");
        require(to != address(0), "ERC721: transfer to the zero address");
        require(_owners[tokenId] == from, "ERC721: transfer from incorrect owner");

        _tokenApprovals[tokenId] = address(0);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                require(retval == IERC721Receiver.onERC721Received.selector, "ERC721: transfer to non ERC721Receiver implementer");
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function mint(address to, string memory uri) external payable {
        require(!_paused, "Contract is paused");
        require(msg.value >= 0.05 ether, "Insufficient payment");
        require(_currentTokenId <= 10000, "Max supply reached");
        require(to != address(0), "ERC721: mint to the zero address");
        require(_owners[_currentTokenId] == address(0), "ERC721: token already minted");

        _balances[to] += 1;
        _owners[_currentTokenId] = to;
        _tokenURIs[_currentTokenId] = uri;

        emit Transfer(address(0), to, _currentTokenId);
        _currentTokenId += 1;
    }

    function ownerMint(address to, string memory uri) external {
        require(msg.sender == _contractOwner, "Only owner can call this");
        require(!_paused, "Contract is paused");
        require(_currentTokenId <= 10000, "Max supply reached");
        require(to != address(0), "ERC721: mint to the zero address");
        require(_owners[_currentTokenId] == address(0), "ERC721: token already minted");

        _balances[to] += 1;
        _owners[_currentTokenId] = to;
        _tokenURIs[_currentTokenId] = uri;

        emit Transfer(address(0), to, _currentTokenId);
        _currentTokenId += 1;
    }

    function batchMint(address[] memory recipients, string[] memory uris) external {
        require(msg.sender == _contractOwner, "Only owner can call this");
        require(!_paused, "Contract is paused");
        require(recipients.length == uris.length, "Arrays length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(_currentTokenId <= 10000, "Max supply reached");
            require(recipients[i] != address(0), "ERC721: mint to the zero address");
            require(_owners[_currentTokenId] == address(0), "ERC721: token already minted");

            _balances[recipients[i]] += 1;
            _owners[_currentTokenId] = recipients[i];
            _tokenURIs[_currentTokenId] = uris[i];

            emit Transfer(address(0), recipients[i], _currentTokenId);
            _currentTokenId += 1;
        }
    }

    function setTokenURI(uint256 tokenId, string memory uri) external {
        require(msg.sender == _contractOwner, "Only owner can call this");
        require(_owners[tokenId] != address(0), "ERC721: URI set of nonexistent token");
        _tokenURIs[tokenId] = uri;
    }

    function pause() external {
        require(msg.sender == _contractOwner, "Only owner can call this");
        _paused = true;
    }

    function unpause() external {
        require(msg.sender == _contractOwner, "Only owner can call this");
        _paused = false;
    }

    function setMaxSupply(uint256 newMaxSupply) external {
        require(msg.sender == _contractOwner, "Only owner can call this");
        require(newMaxSupply >= _currentTokenId - 1, "Cannot set max supply below current supply");
        _maxSupply = newMaxSupply;
    }

    function setMintPrice(uint256 newPrice) external {
        require(msg.sender == _contractOwner, "Only owner can call this");
        _mintPrice = newPrice;
    }

    function withdraw() external {
        require(msg.sender == _contractOwner, "Only owner can call this");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(_contractOwner).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == _contractOwner, "Only owner can call this");
        require(newOwner != address(0), "New owner cannot be zero address");
        _contractOwner = newOwner;
    }

    function totalSupply() external view returns (uint256) {
        return _currentTokenId - 1;
    }

    function maxSupply() external view returns (uint256) {
        return _maxSupply;
    }

    function mintPrice() external view returns (uint256) {
        return _mintPrice;
    }

    function owner() external view returns (address) {
        return _contractOwner;
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_owners[tokenId] != address(0), "ERC721: operator query for nonexistent token");
        address owner = _owners[tokenId];
        return (spender == owner || _tokenApprovals[tokenId] == spender || _operatorApprovals[owner][spender]);
    }
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}
