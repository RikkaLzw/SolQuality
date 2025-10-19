
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address creator;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool completed;
        bool withdrawn;
        string title;
        string description;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(address => uint256[]) public userCampaigns;

    uint256 public campaignCounter;
    uint256 public platformFee = 25;
    address public owner;

    event CampaignCreated(uint256 campaignId, address creator, uint256 goal);
    event ContributionMade(uint256 campaignId, address contributor, uint256 amount);
    event CampaignCompleted(uint256 campaignId);
    event FundsWithdrawn(uint256 campaignId, uint256 amount);

    error InvalidAmount();
    error NotFound();
    error AccessDenied();
    error InvalidState();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createCampaign(
        uint256 _goal,
        uint256 _duration,
        string memory _title,
        string memory _description
    ) external {
        require(_goal > 0);
        require(_duration > 0);
        require(bytes(_title).length > 0);

        campaigns[campaignCounter] = Campaign({
            creator: msg.sender,
            goal: _goal,
            raised: 0,
            deadline: block.timestamp + _duration,
            completed: false,
            withdrawn: false,
            title: _title,
            description: _description
        });

        userCampaigns[msg.sender].push(campaignCounter);

        emit CampaignCreated(campaignCounter, msg.sender, _goal);
        campaignCounter++;
    }

    function contribute(uint256 _campaignId) external payable validCampaign(_campaignId) {
        require(msg.value > 0);

        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline);
        require(!campaign.completed);

        contributions[_campaignId][msg.sender] += msg.value;
        campaign.raised += msg.value;

        if (campaign.raised >= campaign.goal) {
            campaign.completed = true;
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId) external validCampaign(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator);
        require(campaign.completed);
        require(!campaign.withdrawn);
        require(campaign.raised > 0);

        campaign.withdrawn = true;

        uint256 fee = (campaign.raised * platformFee) / 1000;
        uint256 creatorAmount = campaign.raised - fee;

        payable(owner).transfer(fee);
        payable(campaign.creator).transfer(creatorAmount);

        emit FundsWithdrawn(_campaignId, creatorAmount);
    }

    function refund(uint256 _campaignId) external validCampaign(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline);
        require(!campaign.completed);
        require(!campaign.withdrawn);

        uint256 contributedAmount = contributions[_campaignId][msg.sender];
        require(contributedAmount > 0);

        contributions[_campaignId][msg.sender] = 0;
        campaign.raised -= contributedAmount;

        payable(msg.sender).transfer(contributedAmount);
    }

    function extendDeadline(uint256 _campaignId, uint256 _additionalTime) external validCampaign(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator);
        require(!campaign.completed);
        require(block.timestamp < campaign.deadline);
        require(_additionalTime > 0);

        campaign.deadline += _additionalTime;
    }

    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 100);
        platformFee = _newFee;
    }

    function emergencyWithdraw(uint256 _campaignId) external onlyOwner validCampaign(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.raised > 0);
        require(!campaign.withdrawn);

        campaign.withdrawn = true;
        payable(owner).transfer(campaign.raised);
    }

    function getCampaignDetails(uint256 _campaignId) external view validCampaign(_campaignId) returns (
        address creator,
        uint256 goal,
        uint256 raised,
        uint256 deadline,
        bool completed,
        bool withdrawn,
        string memory title,
        string memory description
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.completed,
            campaign.withdrawn,
            campaign.title,
            campaign.description
        );
    }

    function getUserCampaigns(address _user) external view returns (uint256[] memory) {
        return userCampaigns[_user];
    }

    function getContribution(uint256 _campaignId, address _contributor) external view returns (uint256) {
        return contributions[_campaignId][_contributor];
    }

    function isActive(uint256 _campaignId) external view validCampaign(_campaignId) returns (bool) {
        Campaign storage campaign = campaigns[_campaignId];
        return block.timestamp < campaign.deadline && !campaign.completed;
    }

    function getTimeRemaining(uint256 _campaignId) external view validCampaign(_campaignId) returns (uint256) {
        Campaign storage campaign = campaigns[_campaignId];
        if (block.timestamp >= campaign.deadline) {
            return 0;
        }
        return campaign.deadline - block.timestamp;
    }
}
