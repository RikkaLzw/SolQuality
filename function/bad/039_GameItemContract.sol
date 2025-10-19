
pragma solidity ^0.8.0;

contract GameItemContract {
    struct Item {
        uint256 id;
        string name;
        uint256 rarity;
        uint256 durability;
        uint256 attack;
        uint256 defense;
        address owner;
        bool isEquipped;
        uint256 level;
        uint256 experience;
    }

    mapping(uint256 => Item) public items;
    mapping(address => uint256[]) public playerItems;
    mapping(address => uint256) public playerGold;
    mapping(address => bool) public registeredPlayers;

    uint256 public nextItemId = 1;
    address public gameAdmin;

    event ItemCreated(uint256 itemId, address owner);
    event ItemUpgraded(uint256 itemId, uint256 newLevel);
    event ItemTransferred(uint256 itemId, address from, address to);

    constructor() {
        gameAdmin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == gameAdmin, "Only admin");
        _;
    }

    modifier onlyItemOwner(uint256 itemId) {
        require(items[itemId].owner == msg.sender, "Not item owner");
        _;
    }




    function createAndConfigureItemWithPlayerUpdate(
        address player,
        string memory itemName,
        uint256 rarity,
        uint256 attack,
        uint256 defense,
        uint256 initialGold,
        bool autoEquip
    ) public onlyAdmin returns (uint256) {

        uint256 itemId = nextItemId++;
        items[itemId] = Item({
            id: itemId,
            name: itemName,
            rarity: rarity,
            durability: 100,
            attack: attack,
            defense: defense,
            owner: player,
            isEquipped: false,
            level: 1,
            experience: 0
        });


        if (!registeredPlayers[player]) {
            registeredPlayers[player] = true;
            playerGold[player] = initialGold;
        }

        playerItems[player].push(itemId);


        if (autoEquip) {
            for (uint256 i = 0; i < playerItems[player].length; i++) {
                if (items[playerItems[player][i]].isEquipped) {
                    items[playerItems[player][i]].isEquipped = false;
                }
            }
            items[itemId].isEquipped = true;
        }

        emit ItemCreated(itemId, player);
        return itemId;
    }


    function calculateItemPower(uint256 itemId) public view returns (uint256) {
        Item memory item = items[itemId];
        return (item.attack + item.defense) * item.level * item.rarity;
    }


    function upgradeItemWithComplexLogic(uint256 itemId) public onlyItemOwner(itemId) {
        Item storage item = items[itemId];

        if (item.level < 10) {
            if (item.experience >= item.level * 100) {
                if (item.rarity >= 3) {
                    if (item.durability > 50) {
                        if (playerGold[msg.sender] >= item.level * 1000) {
                            playerGold[msg.sender] -= item.level * 1000;
                            item.level++;
                            item.experience = 0;
                            item.attack += item.rarity * 5;
                            item.defense += item.rarity * 3;

                            if (item.level % 5 == 0) {
                                if (item.rarity < 5) {
                                    item.rarity++;
                                    if (item.rarity == 5) {
                                        item.attack *= 2;
                                        item.defense *= 2;
                                    }
                                }
                            }

                            emit ItemUpgraded(itemId, item.level);
                        } else {
                            revert("Insufficient gold");
                        }
                    } else {
                        revert("Item durability too low");
                    }
                } else {
                    revert("Item rarity too low");
                }
            } else {
                revert("Insufficient experience");
            }
        } else {
            revert("Max level reached");
        }
    }

    function transferItem(uint256 itemId, address to) public onlyItemOwner(itemId) {
        require(to != address(0), "Invalid address");
        require(registeredPlayers[to], "Recipient not registered");

        address from = items[itemId].owner;
        items[itemId].owner = to;
        items[itemId].isEquipped = false;


        uint256[] storage fromItems = playerItems[from];
        for (uint256 i = 0; i < fromItems.length; i++) {
            if (fromItems[i] == itemId) {
                fromItems[i] = fromItems[fromItems.length - 1];
                fromItems.pop();
                break;
            }
        }


        playerItems[to].push(itemId);

        emit ItemTransferred(itemId, from, to);
    }

    function addExperience(uint256 itemId, uint256 exp) public onlyItemOwner(itemId) {
        items[itemId].experience += exp;
    }

    function repairItem(uint256 itemId) public onlyItemOwner(itemId) {
        uint256 cost = (100 - items[itemId].durability) * 10;
        require(playerGold[msg.sender] >= cost, "Insufficient gold");

        playerGold[msg.sender] -= cost;
        items[itemId].durability = 100;
    }

    function equipItem(uint256 itemId) public onlyItemOwner(itemId) {

        uint256[] memory userItems = playerItems[msg.sender];
        for (uint256 i = 0; i < userItems.length; i++) {
            items[userItems[i]].isEquipped = false;
        }

        items[itemId].isEquipped = true;
    }

    function getPlayerItems(address player) public view returns (uint256[] memory) {
        return playerItems[player];
    }

    function registerPlayer() public {
        require(!registeredPlayers[msg.sender], "Already registered");
        registeredPlayers[msg.sender] = true;
        playerGold[msg.sender] = 1000;
    }
}
