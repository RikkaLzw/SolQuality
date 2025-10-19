
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

    event ItemCreated(uint256 itemId, string name, uint256 rarity);
    event ItemTransferred(address from, address to, uint256 itemId);
    event ItemUsed(address player, uint256 itemId);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier itemExists(uint256 _itemId) {
        require(items[_itemId].exists);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createItem(string memory _name, uint256 _rarity, uint256 _durability) external onlyOwner {
        require(_rarity > 0 && _rarity <= 5);
        require(_durability > 0);
        require(bytes(_name).length > 0);

        items[nextItemId] = Item({
            id: nextItemId,
            name: _name,
            rarity: _rarity,
            durability: _durability,
            exists: true
        });

        totalItems++;
        emit ItemCreated(nextItemId, _name, _rarity);
        nextItemId++;
    }

    function mintItem(address _to, uint256 _itemId) external onlyOwner itemExists(_itemId) {
        require(_to != address(0));

        playerItems[_to][_itemId]++;
        playerItemList[_to].push(_itemId);

    }

    function transferItem(address _to, uint256 _itemId, uint256 _amount) external itemExists(_itemId) {
        require(_to != address(0));
        require(playerItems[msg.sender][_itemId] >= _amount);

        playerItems[msg.sender][_itemId] -= _amount;
        playerItems[_to][_itemId] += _amount;

        emit ItemTransferred(msg.sender, _to, _itemId);
    }

    function useItem(uint256 _itemId) external itemExists(_itemId) {
        require(playerItems[msg.sender][_itemId] > 0);

        playerItems[msg.sender][_itemId]--;

        if (items[_itemId].durability > 0) {
            items[_itemId].durability--;
        }

        emit ItemUsed(msg.sender, _itemId);

    }

    function upgradeItem(uint256 _itemId) external itemExists(_itemId) {
        require(playerItems[msg.sender][_itemId] > 0);
        require(items[_itemId].rarity < 5);

        items[_itemId].rarity++;

    }

    function repairItem(uint256 _itemId, uint256 _durabilityAmount) external itemExists(_itemId) {
        require(playerItems[msg.sender][_itemId] > 0);
        require(_durabilityAmount > 0);

        items[_itemId].durability += _durabilityAmount;
    }

    function burnItem(uint256 _itemId, uint256 _amount) external itemExists(_itemId) {
        if (playerItems[msg.sender][_itemId] < _amount) {
            revert Error1();
        }

        playerItems[msg.sender][_itemId] -= _amount;
        totalItems -= _amount;
    }

    function setItemName(uint256 _itemId, string memory _newName) external onlyOwner itemExists(_itemId) {
        if (bytes(_newName).length == 0) {
            revert Error2();
        }

        items[_itemId].name = _newName;
    }

    function removeItem(uint256 _itemId) external onlyOwner itemExists(_itemId) {
        if (totalItems == 0) {
            revert Error3();
        }

        delete items[_itemId];
        totalItems--;
    }

    function getPlayerItemCount(address _player, uint256 _itemId) external view returns (uint256) {
        return playerItems[_player][_itemId];
    }

    function getPlayerItems(address _player) external view returns (uint256[] memory) {
        return playerItemList[_player];
    }

    function getItemInfo(uint256 _itemId) external view returns (Item memory) {
        require(items[_itemId].exists);
        return items[_itemId];
    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }
}
