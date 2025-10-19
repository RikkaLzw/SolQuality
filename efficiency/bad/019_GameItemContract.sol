
pragma solidity ^0.8.0;

contract GameItemContract {
    struct GameItem {
        uint256 id;
        string name;
        uint256 rarity;
        uint256 attack;
        uint256 defense;
        uint256 price;
        bool exists;
    }


    GameItem[] public gameItems;


    uint256 public tempCalculation;
    uint256 public anotherTempVar;

    mapping(address => uint256[]) public playerItems;
    mapping(address => uint256) public playerGold;

    address public owner;
    uint256 public totalItems;

    event ItemCreated(uint256 indexed itemId, string name, uint256 rarity);
    event ItemPurchased(address indexed player, uint256 indexed itemId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalItems = 0;
    }

    function createItem(
        string memory _name,
        uint256 _rarity,
        uint256 _attack,
        uint256 _defense,
        uint256 _price
    ) external onlyOwner {

        uint256 newItemId = totalItems;
        totalItems = totalItems + 1;

        GameItem memory newItem = GameItem({
            id: newItemId,
            name: _name,
            rarity: _rarity,
            attack: _attack,
            defense: _defense,
            price: _price,
            exists: true
        });

        gameItems.push(newItem);


        for (uint256 i = 0; i < gameItems.length; i++) {
            tempCalculation = gameItems[i].attack + gameItems[i].defense;
        }

        emit ItemCreated(newItemId, _name, _rarity);
    }

    function purchaseItem(uint256 _itemId) external payable {
        require(_itemId < gameItems.length, "Item does not exist");
        require(gameItems[_itemId].exists, "Item not available");


        require(msg.value >= gameItems[_itemId].price, "Insufficient payment");
        require(playerGold[msg.sender] >= gameItems[_itemId].price, "Insufficient gold");

        playerGold[msg.sender] -= gameItems[_itemId].price;
        playerItems[msg.sender].push(_itemId);


        uint256 bonus = calculateItemBonus(_itemId);
        uint256 sameBonus = calculateItemBonus(_itemId);
        uint256 anotherSameBonus = calculateItemBonus(_itemId);


        tempCalculation = bonus + sameBonus + anotherSameBonus;
        anotherTempVar = tempCalculation / 3;

        emit ItemPurchased(msg.sender, _itemId);
    }

    function calculateItemBonus(uint256 _itemId) public view returns (uint256) {
        require(_itemId < gameItems.length, "Item does not exist");


        return gameItems[_itemId].attack * gameItems[_itemId].rarity +
               gameItems[_itemId].defense * gameItems[_itemId].rarity;
    }

    function getPlayerItems(address _player) external view returns (uint256[] memory) {
        return playerItems[_player];
    }

    function getItemDetails(uint256 _itemId) external view returns (
        uint256 id,
        string memory name,
        uint256 rarity,
        uint256 attack,
        uint256 defense,
        uint256 price
    ) {
        require(_itemId < gameItems.length, "Item does not exist");

        GameItem memory item = gameItems[_itemId];
        return (item.id, item.name, item.rarity, item.attack, item.defense, item.price);
    }

    function addGold(address _player, uint256 _amount) external onlyOwner {
        playerGold[_player] += _amount;
    }

    function getAllItemsCount() external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < gameItems.length; i++) {
            if (gameItems[i].exists) {
                count++;
            }
        }
        return count;
    }

    function batchUpdateItemPrices(uint256[] memory _itemIds, uint256[] memory _newPrices) external onlyOwner {
        require(_itemIds.length == _newPrices.length, "Arrays length mismatch");


        for (uint256 i = 0; i < _itemIds.length; i++) {
            require(_itemIds[i] < gameItems.length, "Item does not exist");
            gameItems[_itemIds[i]].price = _newPrices[i];


            tempCalculation = gameItems[_itemIds[i]].price * 2;
            anotherTempVar = tempCalculation + gameItems[_itemIds[i]].attack;
        }
    }

    function calculateTotalValue() external view returns (uint256) {
        uint256 total = 0;


        for (uint256 i = 0; i < gameItems.length; i++) {

            total += gameItems[i].price + gameItems[i].attack + gameItems[i].defense;


            uint256 itemValue = gameItems[i].price + gameItems[i].attack + gameItems[i].defense;
            uint256 sameItemValue = gameItems[i].price + gameItems[i].attack + gameItems[i].defense;
        }

        return total;
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
