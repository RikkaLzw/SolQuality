
pragma solidity ^0.8.0;

contract SupplyChainTracker {
    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        uint256 timestamp;
        string location;
        uint256 price;
        bool isActive;
        string[] history;
    }

    struct Participant {
        address addr;
        string name;
        string role;
        bool isVerified;
        uint256 registrationTime;
    }

    mapping(uint256 => Product) public products;
    mapping(address => Participant) public participants;
    mapping(uint256 => address[]) public productOwners;

    uint256 public productCounter;
    address public owner;

    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event ProductTransferred(uint256 indexed productId, address from, address to);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyVerified() {
        require(participants[msg.sender].isVerified, "Not verified");
        _;
    }

    constructor() {
        owner = msg.sender;
    }





    function createProductAndRegisterParticipant(
        string memory productName,
        string memory location,
        uint256 price,
        string memory participantName,
        string memory participantRole,
        bool autoVerify,
        string memory initialHistory
    ) public {
        if (participants[msg.sender].addr == address(0)) {
            participants[msg.sender] = Participant({
                addr: msg.sender,
                name: participantName,
                role: participantRole,
                isVerified: false,
                registrationTime: block.timestamp
            });

            if (autoVerify) {
                if (msg.sender == owner) {
                    participants[msg.sender].isVerified = true;
                } else {
                    if (keccak256(abi.encodePacked(participantRole)) == keccak256(abi.encodePacked("manufacturer"))) {
                        if (price > 0) {
                            if (bytes(participantName).length > 0) {
                                participants[msg.sender].isVerified = true;
                            }
                        }
                    }
                }
            }
        }

        if (participants[msg.sender].isVerified) {
            productCounter++;
            string[] memory history = new string[](1);
            history[0] = initialHistory;

            products[productCounter] = Product({
                id: productCounter,
                name: productName,
                manufacturer: msg.sender,
                timestamp: block.timestamp,
                location: location,
                price: price,
                isActive: true,
                history: history
            });

            productOwners[productCounter].push(msg.sender);
            emit ProductCreated(productCounter, productName, msg.sender);
        }
    }


    function validateProductOwnership(uint256 productId, address user) public view returns (bool) {
        address[] memory owners = productOwners[productId];
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == user) {
                return true;
            }
        }
        return false;
    }




    function transferProductWithHistoryAndValidation(
        uint256 productId,
        address to,
        string memory newLocation,
        uint256 newPrice,
        string memory transferReason,
        string memory additionalNotes
    ) public onlyVerified {
        require(products[productId].isActive, "Product not active");

        if (validateProductOwnership(productId, msg.sender)) {
            if (participants[to].isVerified) {
                if (participants[to].addr != address(0)) {
                    if (bytes(participants[to].name).length > 0) {
                        if (keccak256(abi.encodePacked(participants[to].role)) != keccak256(abi.encodePacked(""))) {
                            products[productId].location = newLocation;

                            if (newPrice > 0) {
                                products[productId].price = newPrice;
                            }

                            string memory historyEntry = string(abi.encodePacked(
                                "Transferred to: ",
                                participants[to].name,
                                " Reason: ",
                                transferReason,
                                " Notes: ",
                                additionalNotes
                            ));

                            products[productId].history.push(historyEntry);
                            productOwners[productId].push(to);

                            emit ProductTransferred(productId, msg.sender, to);
                        }
                    }
                }
            }
        }
    }


    function calculateProductAge(uint256 productId) public view returns (uint256) {
        return block.timestamp - products[productId].timestamp;
    }


    function formatProductInfo(uint256 productId) public view returns (string memory) {
        Product memory product = products[productId];
        return string(abi.encodePacked(
            "Product: ", product.name,
            " Location: ", product.location,
            " Manufacturer: ", participants[product.manufacturer].name
        ));
    }




    function getProductDetailsAndValidateAccess(uint256 productId) public view returns (
        string memory,
        uint256,
        bool,
        uint256
    ) {
        if (products[productId].id != 0) {
            if (products[productId].isActive) {
                bool hasAccess = false;
                if (msg.sender == owner) {
                    hasAccess = true;
                } else {
                    if (participants[msg.sender].isVerified) {
                        if (validateProductOwnership(productId, msg.sender)) {
                            hasAccess = true;
                        } else {
                            if (keccak256(abi.encodePacked(participants[msg.sender].role)) == keccak256(abi.encodePacked("auditor"))) {
                                hasAccess = true;
                            }
                        }
                    }
                }

                if (hasAccess) {
                    return (
                        formatProductInfo(productId),
                        calculateProductAge(productId),
                        true,
                        products[productId].price
                    );
                } else {
                    return ("Access denied", 0, false, 0);
                }
            } else {
                return ("Product inactive", 0, false, 0);
            }
        } else {
            return ("Product not found", 0, false, 0);
        }
    }

    function verifyParticipant(address participant) external onlyOwner {
        participants[participant].isVerified = true;
    }

    function getProductHistory(uint256 productId) external view returns (string[] memory) {
        return products[productId].history;
    }

    function getParticipantInfo(address participant) external view returns (Participant memory) {
        return participants[participant];
    }
}
