
pragma solidity ^0.8.0;

contract GameItemContract {
    struct Item {
        uint256 id;
        string name;
        uint256 rarity;
        uint256 durability;
        bool exists;
    }

    mapping(uint256 => Item) public items;
    mapping(address => mapping(uint256 => uint256)) public playerItems;
    mapping(address => uint256[]) public playerItemList;

    address public owner;
    uint256 public nextItemId = 1;
    uint256 public totalItems;

    error Error1();
    error Error2();
    error Error3();

    event ItemCreated(uint256 itemId, string name);
    event ItemTransferred(address from, address to, uint256 itemId);
    event ItemUsed(address player, uint256 itemId);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createItem(string memory _name, uint256 _rarity, uint256 _durability) external onlyOwner {
        require(bytes(_name).length > 0);
        require(_rarity > 0 && _rarity <= 5);
        require(_durability > 0);

        items[nextItemId] = Item({
            id: nextItemId,
            name: _name,
            rarity: _rarity,
            durability: _durability,
            exists: true
        });

        totalItems++;
        nextItemId++;

        emit ItemCreated(nextItemId - 1, _name);
    }

    function giveItemToPlayer(address _player, uint256 _itemId, uint256 _quantity) external onlyOwner {
        require(_player != address(0));
        require(items[_itemId].exists);
        require(_quantity > 0);

        if (playerItems[_player][_itemId] == 0) {
            playerItemList[_player].push(_itemId);
        }

        playerItems[_player][_itemId] += _quantity;
    }

    function transferItem(address _to, uint256 _itemId, uint256 _quantity) external {
        require(_to != address(0));
        require(_to != msg.sender);
        require(items[_itemId].exists);
        require(playerItems[msg.sender][_itemId] >= _quantity);
        require(_quantity > 0);

        playerItems[msg.sender][_itemId] -= _quantity;

        if (playerItems[_to][_itemId] == 0) {
            playerItemList[_to].push(_itemId);
        }

        playerItems[_to][_itemId] += _quantity;

        emit ItemTransferred(msg.sender, _to, _itemId);
    }

    function useItem(uint256 _itemId, uint256 _quantity) external {
        require(items[_itemId].exists);
        require(playerItems[msg.sender][_itemId] >= _quantity);
        require(_quantity > 0);

        playerItems[msg.sender][_itemId] -= _quantity;

        emit ItemUsed(msg.sender, _itemId);
    }

    function upgradeItem(uint256 _itemId) external {
        require(items[_itemId].exists);
        require(playerItems[msg.sender][_itemId] > 0);

        if (items[_itemId].rarity >= 5) {
            revert Error1();
        }

        items[_itemId].rarity++;
        items[_itemId].durability += 10;
    }

    function repairItem(uint256 _itemId) external payable {
        require(items[_itemId].exists);
        require(playerItems[msg.sender][_itemId] > 0);
        require(msg.value >= 0.001 ether);

        if (items[_itemId].durability >= 100) {
            revert Error2();
        }

        items[_itemId].durability = 100;
    }

    function destroyItem(uint256 _itemId, uint256 _quantity) external {
        require(items[_itemId].exists);
        require(playerItems[msg.sender][_itemId] >= _quantity);
        require(_quantity > 0);

        playerItems[msg.sender][_itemId] -= _quantity;
    }

    function getPlayerItems(address _player) external view returns (uint256[] memory) {
        return playerItemList[_player];
    }

    function getPlayerItemQuantity(address _player, uint256 _itemId) external view returns (uint256) {
        return playerItems[_player][_itemId];
    }

    function getItemInfo(uint256 _itemId) external view returns (Item memory) {
        require(items[_itemId].exists);
        return items[_itemId];
    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
