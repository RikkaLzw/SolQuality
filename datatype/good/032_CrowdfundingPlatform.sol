
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        bytes32 title;
        bytes32 description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint32 deadline;
        bool isActive;
        bool goalReached;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public platformFeeRate;
    address payable public platformOwner;

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        bytes32 title,
        uint256 targetAmount,
        uint32 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignSuccessful(
        uint256 indexed campaignId,
        uint256 totalRaised
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
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
        require(block.timestamp <= campaigns[_campaignId].deadline, "Campaign expired");
        _;
    }

    constructor(uint256 _platformFeeRate) {
        require(_platformFeeRate <= 1000, "Fee rate too high");
        platformOwner = payable(msg.sender);
        platformFeeRate = _platformFeeRate;
        campaignCounter = 0;
    }

    function createCampaign(
        bytes32 _title,
        bytes32 _description,
        uint256 _targetAmount,
        uint32 _durationInDays
    ) external returns (uint256) {
        require(_targetAmount > 0, "Target amount must be positive");
        require(_durationInDays > 0 && _durationInDays <= 365, "Invalid duration");

        uint256 campaignId = campaignCounter;
        Campaign storage newCampaign = campaigns[campaignId];

        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.targetAmount = _targetAmount;
        newCampaign.raisedAmount = 0;
        newCampaign.deadline = uint32(block.timestamp + (_durationInDays * 1 days));
        newCampaign.isActive = true;
        newCampaign.goalReached = false;

        campaignCounter++;

        emit CampaignCreated(
            campaignId,
            msg.sender,
            _title,
            _targetAmount,
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


        if (campaign.raisedAmount >= campaign.targetAmount && !campaign.goalReached) {
            campaign.goalReached = true;
            emit CampaignSuccessful(_campaignId, campaign.raisedAmount);
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId)
        external
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only creator can withdraw");
        require(campaign.goalReached, "Goal not reached");
        require(campaign.raisedAmount > 0, "No funds to withdraw");

        uint256 totalAmount = campaign.raisedAmount;
        uint256 platformFee = (totalAmount * platformFeeRate) / 10000;
        uint256 creatorAmount = totalAmount - platformFee;

        campaign.raisedAmount = 0;
        campaign.isActive = false;


        if (platformFee > 0) {
            platformOwner.transfer(platformFee);
        }


        campaign.creator.transfer(creatorAmount);

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
    }

    function refund(uint256 _campaignId)
        external
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp > campaign.deadline, "Campaign still active");
        require(!campaign.goalReached, "Goal was reached");

        uint256 contributionAmount = campaign.contributions[msg.sender];
        require(contributionAmount > 0, "No contribution found");

        campaign.contributions[msg.sender] = 0;
        campaign.raisedAmount -= contributionAmount;

        payable(msg.sender).transfer(contributionAmount);

        emit RefundIssued(_campaignId, msg.sender, contributionAmount);
    }

    function getCampaignInfo(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (
            address creator,
            bytes32 title,
            bytes32 description,
            uint256 targetAmount,
            uint256 raisedAmount,
            uint32 deadline,
            bool isActive,
            bool goalReached
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.targetAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached
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

    function getContributorsCount(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return campaigns[_campaignId].contributors.length;
    }

    function setPlatformFeeRate(uint256 _newFeeRate)
        external
        onlyPlatformOwner
    {
        require(_newFeeRate <= 1000, "Fee rate too high");
        platformFeeRate = _newFeeRate;
    }

    function transferPlatformOwnership(address payable _newOwner)
        external
        onlyPlatformOwner
    {
        require(_newOwner != address(0), "Invalid address");
        platformOwner = _newOwner;
    }
}
