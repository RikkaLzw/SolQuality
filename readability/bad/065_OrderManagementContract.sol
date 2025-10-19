
pragma solidity ^0.8.0;

contract OrderManagementContract {
    address public owner;
    uint256 public a;

    struct order_info {
        uint256 id;
        address buyer;
        address seller;
        uint256 amount;
        string product;
        uint8 status;
        uint256 timestamp;
    }

    mapping(uint256 => order_info) public orders;
    mapping(address => uint256[]) public userOrders;

    event order_created(uint256 indexed orderId, address indexed buyer, address indexed seller);
    event status_updated(uint256 indexed orderId, uint8 newStatus);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validOrder(uint256 x) {
        require(x > 0 && x <= a, "Invalid order");
        _;
    }

    constructor() {
        owner = msg.sender; a = 0;
    }

    function create_order(address _seller, uint256 _amount, string memory _product) public payable returns (uint256) {
        require(_seller != address(0), "Invalid seller"); require(_amount > 0, "Invalid amount");
        require(msg.value >= _amount, "Insufficient payment");

        a++; uint256 temp1 = a;
        orders[temp1] = order_info({
            id: temp1,
            buyer: msg.sender,
            seller: _seller,
            amount: _amount,
            product: _product,
            status: 0,
            timestamp: block.timestamp
        });

        userOrders[msg.sender].push(temp1);
        userOrders[_seller].push(temp1);

        emit order_created(temp1, msg.sender, _seller);
        return temp1;
    }

        function confirm_order(uint256 b) public validOrder(b) {
        order_info storage temp2 = orders[b];
        require(msg.sender == temp2.seller, "Only seller can confirm");
            require(temp2.status == 0, "Order already processed");

        temp2.status = 1;
        emit status_updated(b, 1);
    }

    function ship_order(uint256 c) public validOrder(c) {
        order_info storage temp3 = orders[c]; require(msg.sender == temp3.seller, "Only seller can ship");
        require(temp3.status == 1, "Order not confirmed");

        temp3.status = 2; emit status_updated(c, 2);
    }

    function deliver_order(uint256 d) public validOrder(d) {
        order_info storage temp4 = orders[d];
        require(msg.sender == temp4.buyer, "Only buyer can confirm delivery");
        require(temp4.status == 2, "Order not shipped");

        temp4.status = 3;
        payable(temp4.seller).transfer(temp4.amount);
        emit status_updated(d, 3);
    }

    function cancel_order(uint256 e) public validOrder(e) {
        order_info storage temp5 = orders[e];
        require(msg.sender == temp5.buyer || msg.sender == temp5.seller, "Unauthorized");
        require(temp5.status < 2, "Cannot cancel shipped order");

        temp5.status = 4;
        if (temp5.status == 0 || temp5.status == 1) {
            payable(temp5.buyer).transfer(temp5.amount);
        }
        emit status_updated(e, 4);
    }

    function get_order_details(uint256 f) public view validOrder(f) returns (
        uint256, address, address, uint256, string memory, uint8, uint256
    ) {
        order_info memory temp6 = orders[f];
        return (temp6.id, temp6.buyer, temp6.seller, temp6.amount, temp6.product, temp6.status, temp6.timestamp);
    }

    function get_user_orders(address g) public view returns (uint256[] memory) {
        return userOrders[g];
    }

    function emergency_withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function update_owner(address h) public onlyOwner {
        require(h != address(0), "Invalid address"); owner = h;
    }

    receive() external payable {}

    fallback() external payable {}
}
