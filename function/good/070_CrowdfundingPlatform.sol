
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool goalReached;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public platformFeeRate = 250;
    address payable public platformOwner;

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignFinalized(
        uint256 indexed campaignId,
        bool goalReached,
        uint256 totalRaised
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign not active");
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign expired");
        _;
    }

    constructor() {
        platformOwner = payable(msg.sender);
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_goalAmount > 0, "Goal amount must be positive");
        require(_durationInDays > 0, "Duration must be positive");

        uint256 campaignId = campaignCounter;
        Campaign storage newCampaign = campaigns[campaignId];

        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.deadline = block.timestamp + (_durationInDays * 1 days);
        newCampaign.isActive = true;

        campaignCounter++;

        emit CampaignCreated(
            campaignId,
            msg.sender,
            _title,
            _goalAmount,
            newCampaign.deadline
        );

        return campaignId;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        campaignExists(_campaignId)
        campaignActive(_campaignId)
    {
        require(msg.value > 0, "Contribution must be positive");

        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender != campaign.creator, "Creator cannot contribute");

        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }

        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;

        if (campaign.raisedAmount >= campaign.goalAmount) {
            campaign.goalReached = true;
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function finalizeCampaign(uint256 _campaignId)
        external
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.isActive, "Campaign already finalized");
        require(
            block.timestamp >= campaign.deadline || campaign.goalReached,
            "Campaign still active"
        );

        campaign.isActive = false;

        if (campaign.goalReached) {
            _distributeFunds(_campaignId);
        }

        emit CampaignFinalized(_campaignId, campaign.goalReached, campaign.raisedAmount);
    }

    function claimRefund(uint256 _campaignId)
        external
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(!campaign.isActive, "Campaign still active");
        require(!campaign.goalReached, "Goal was reached");

        uint256 contribution = campaign.contributions[msg.sender];
        require(contribution > 0, "No contribution found");

        campaign.contributions[msg.sender] = 0;

        payable(msg.sender).transfer(contribution);

        emit RefundIssued(_campaignId, msg.sender, contribution);
    }

    function getCampaignInfo(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (
            address creator,
            string memory title,
            uint256 goalAmount,
            uint256 raisedAmount
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.goalAmount,
            campaign.raisedAmount
        );
    }

    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return campaigns[_campaignId].contributions[_contributor];
    }

    function getContributorCount(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return campaigns[_campaignId].contributors.length;
    }

    function setPlatformFeeRate(uint256 _newRate)
        external
        onlyPlatformOwner
    {
        require(_newRate <= 1000, "Fee rate too high");
        platformFeeRate = _newRate;
    }

    function _distributeFunds(uint256 _campaignId) private {
        Campaign storage campaign = campaigns[_campaignId];
        uint256 totalAmount = campaign.raisedAmount;
        uint256 platformFee = (totalAmount * platformFeeRate) / 10000;
        uint256 creatorAmount = totalAmount - platformFee;

        if (platformFee > 0) {
            platformOwner.transfer(platformFee);
        }

        campaign.creator.transfer(creatorAmount);
    }

    function emergencyWithdraw() external onlyPlatformOwner {
        platformOwner.transfer(address(this).balance);
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }
}
