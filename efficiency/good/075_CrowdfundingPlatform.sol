
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool withdrawn;
        bool exists;
    }

    struct Contribution {
        uint256 amount;
        bool refunded;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Contribution)) public contributions;
    mapping(uint256 => address[]) private campaignContributors;

    uint256 public nextCampaignId;
    uint256 public platformFeeRate = 250;
    address payable public platformOwner;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goal, uint256 deadline);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event FundsWithdrawn(uint256 indexed campaignId, uint256 amount);
    event RefundClaimed(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Not platform owner");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(campaigns[_campaignId].exists, "Campaign does not exist");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign ended");
        _;
    }

    modifier campaignEnded(uint256 _campaignId) {
        require(block.timestamp >= campaigns[_campaignId].deadline, "Campaign still active");
        _;
    }

    constructor() {
        platformOwner = payable(msg.sender);
    }

    function createCampaign(uint256 _goal, uint256 _duration) external returns (uint256) {
        require(_goal > 0, "Goal must be positive");
        require(_duration > 0, "Duration must be positive");

        uint256 campaignId = nextCampaignId++;
        uint256 deadline = block.timestamp + _duration;

        campaigns[campaignId] = Campaign({
            creator: payable(msg.sender),
            goal: _goal,
            raised: 0,
            deadline: deadline,
            withdrawn: false,
            exists: true
        });

        emit CampaignCreated(campaignId, msg.sender, _goal, deadline);
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
        Contribution storage contribution = contributions[_campaignId][msg.sender];


        uint256 currentAmount = contribution.amount;

        if (currentAmount == 0) {
            campaignContributors[_campaignId].push(msg.sender);
        }

        contribution.amount = currentAmount + msg.value;
        campaign.raised += msg.value;

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId)
        external
        campaignExists(_campaignId)
        campaignEnded(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Not campaign creator");
        require(!campaign.withdrawn, "Funds already withdrawn");
        require(campaign.raised >= campaign.goal, "Goal not reached");

        campaign.withdrawn = true;


        uint256 totalRaised = campaign.raised;
        uint256 platformFee = (totalRaised * platformFeeRate) / 10000;
        uint256 creatorAmount = totalRaised - platformFee;


        if (platformFee > 0) {
            platformOwner.transfer(platformFee);
        }


        campaign.creator.transfer(creatorAmount);

        emit FundsWithdrawn(_campaignId, creatorAmount);
    }

    function claimRefund(uint256 _campaignId)
        external
        campaignExists(_campaignId)
        campaignEnded(_campaignId)
    {
        Campaign memory campaign = campaigns[_campaignId];
        require(campaign.raised < campaign.goal, "Goal was reached");

        Contribution storage contribution = contributions[_campaignId][msg.sender];
        require(contribution.amount > 0, "No contribution found");
        require(!contribution.refunded, "Already refunded");


        uint256 refundAmount = contribution.amount;
        contribution.refunded = true;

        payable(msg.sender).transfer(refundAmount);

        emit RefundClaimed(_campaignId, msg.sender, refundAmount);
    }

    function getCampaignInfo(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (
            address creator,
            uint256 goal,
            uint256 raised,
            uint256 deadline,
            bool withdrawn,
            bool goalReached,
            bool isActive
        )
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.withdrawn,
            campaign.raised >= campaign.goal,
            block.timestamp < campaign.deadline
        );
    }

    function getContributorCount(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return campaignContributors[_campaignId].length;
    }

    function getContributors(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (address[] memory)
    {
        return campaignContributors[_campaignId];
    }

    function setPlatformFeeRate(uint256 _newRate) external onlyPlatformOwner {
        require(_newRate <= 1000, "Fee rate too high");
        platformFeeRate = _newRate;
    }

    function transferPlatformOwnership(address payable _newOwner) external onlyPlatformOwner {
        require(_newOwner != address(0), "Invalid address");
        platformOwner = _newOwner;
    }
}
