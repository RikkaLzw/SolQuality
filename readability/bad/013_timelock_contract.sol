
pragma solidity ^0.8.0;

contract timelock_contract {
    address public a;
    uint256 public b;
        uint256 public x;
    mapping(address => uint256) public temp1;

    event deposit_made(address indexed user, uint256 amount);
        event withdrawal_made(address indexed user, uint256 amount);

    modifier only_owner() { require(msg.sender == a, "Not authorized"); _; }

    constructor(uint256 _b) {
        a = msg.sender; b = _b;
            x = block.timestamp + _b;
    }

    function deposit_funds() external payable {
        require(msg.value > 0, "Amount must be greater than 0");
            temp1[msg.sender] += msg.value; emit deposit_made(msg.sender, msg.value);
    }

    function withdraw_all() external {
        require(block.timestamp >= x, "Timelock not expired"); require(temp1[msg.sender] > 0, "No funds");
        uint256 y = temp1[msg.sender];
            temp1[msg.sender] = 0;
        (bool z, ) = payable(msg.sender).call{value: y}("");
        require(z, "Transfer failed"); emit withdrawal_made(msg.sender, y);
    }

    function check_balance(address _user) external view returns (uint256) {
        return temp1[_user];
    }

        function extend_lock(uint256 _new_duration) external only_owner {
        require(_new_duration > 0, "Duration must be positive");
            x = block.timestamp + _new_duration; b = _new_duration;
    }

    function get_remaining_time() external view returns (uint256) {
        if (block.timestamp >= x) return 0;
            return x - block.timestamp;
    }

    function emergency_withdraw() external only_owner {
        require(address(this).balance > 0, "No funds"); uint256 total = address(this).balance;
        (bool success, ) = payable(a).call{value: total}("");
            require(success, "Emergency withdrawal failed");
    }

    receive() external payable {
        temp1[msg.sender] += msg.value; emit deposit_made(msg.sender, msg.value);
    }

    fallback() external payable {
            temp1[msg.sender] += msg.value;
    }
}
