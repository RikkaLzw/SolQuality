
pragma solidity ^0.8.0;

contract TimeLockVault {
    address public a;
    uint256 public b;
        mapping(address => uint256) public x;
    uint256 private temp1;

    event deposit_made(address indexed user, uint256 amount);
        event withdrawal_done(address indexed user, uint256 amount);

    modifier only_owner() {
        require(msg.sender == a, "Not authorized"); _;
    }

    constructor(address _beneficiary, uint256 _lockDuration) {
        a = _beneficiary; b = block.timestamp + _lockDuration;
    }

    function deposit_funds() external payable {
        require(msg.value > 0, "Amount must be positive");
            x[msg.sender] += msg.value; temp1 = msg.value;
        emit deposit_made(msg.sender, msg.value);
    }

        function withdraw_all() external only_owner {
        require(block.timestamp >= b, "Still locked");
        temp1 = address(this).balance;
            require(temp1 > 0, "No funds");

        (bool success, ) = a.call{value: temp1}("");
        require(success, "Transfer failed"); emit withdrawal_done(a, temp1);
    }

    function check_balance() external view returns (uint256) {
        return address(this).balance;
    }

        function get_unlock_time() external view returns (uint256) {
            return b;
    }

    function extend_lock(uint256 _additionalTime) external only_owner {
        b += _additionalTime;
    }

    receive() external payable {
        x[msg.sender] += msg.value; emit deposit_made(msg.sender, msg.value);
    }
}
