
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool withdrawn;
        bool exists;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => address[]) public contributors;

    uint256 public nextCampaignId;
    uint256 public platformFee = 250;
    address public owner;

    error InvalidInput();
    error NotFound();
    error AccessDenied();
    error Failed();

    event CampaignCreated(uint256 campaignId, address creator, uint256 goal);
    event ContributionMade(uint256 campaignId, address contributor, uint256 amount);
    event FundsWithdrawn(uint256 campaignId, uint256 amount);
    event RefundIssued(uint256 campaignId, address contributor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(campaigns[_campaignId].exists);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _duration
    ) external {
        require(_goal > 0);
        require(_duration > 0);
        require(bytes(_title).length > 0);

        uint256 campaignId = nextCampaignId++;

        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            title: _title,
            description: _description,
            goal: _goal,
            raised: 0,
            deadline: block.timestamp + _duration,
            withdrawn: false,
            exists: true
        });

        emit CampaignCreated(campaignId, msg.sender, _goal);
    }

    function contribute(uint256 _campaignId) external payable campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];

        require(block.timestamp < campaign.deadline);
        require(msg.value > 0);

        if (contributions[_campaignId][msg.sender] == 0) {
            contributors[_campaignId].push(msg.sender);
        }

        contributions[_campaignId][msg.sender] += msg.value;
        campaign.raised += msg.value;

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId) external campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];

        require(msg.sender == campaign.creator);
        require(block.timestamp >= campaign.deadline);
        require(campaign.raised >= campaign.goal);
        require(!campaign.withdrawn);

        campaign.withdrawn = true;

        uint256 fee = (campaign.raised * platformFee) / 10000;
        uint256 amount = campaign.raised - fee;

        payable(owner).transfer(fee);
        payable(campaign.creator).transfer(amount);

        emit FundsWithdrawn(_campaignId, amount);
    }

    function refund(uint256 _campaignId) external campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];

        require(block.timestamp >= campaign.deadline);
        require(campaign.raised < campaign.goal);
        require(contributions[_campaignId][msg.sender] > 0);

        uint256 amount = contributions[_campaignId][msg.sender];
        contributions[_campaignId][msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit RefundIssued(_campaignId, msg.sender, amount);
    }

    function getCampaign(uint256 _campaignId) external view returns (
        address creator,
        string memory title,
        string memory description,
        uint256 goal,
        uint256 raised,
        uint256 deadline,
        bool withdrawn
    ) {
        require(campaigns[_campaignId].exists);

        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.withdrawn
        );
    }

    function getContributors(uint256 _campaignId) external view campaignExists(_campaignId) returns (address[] memory) {
        return contributors[_campaignId];
    }

    function getContribution(uint256 _campaignId, address _contributor) external view returns (uint256) {
        return contributions[_campaignId][_contributor];
    }

    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000);
        platformFee = _newFee;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function isCampaignSuccessful(uint256 _campaignId) external view campaignExists(_campaignId) returns (bool) {
        Campaign memory campaign = campaigns[_campaignId];
        return campaign.raised >= campaign.goal && block.timestamp >= campaign.deadline;
    }

    function isCampaignActive(uint256 _campaignId) external view campaignExists(_campaignId) returns (bool) {
        return block.timestamp < campaigns[_campaignId].deadline;
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }
}
