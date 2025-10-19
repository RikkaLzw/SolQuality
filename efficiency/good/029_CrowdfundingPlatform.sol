
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrowdfundingPlatform is ReentrancyGuard, Ownable {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool withdrawn;
        bool active;
    }

    struct Contribution {
        uint256 amount;
        bool refunded;
    }


    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Contribution)) public contributions;
    mapping(address => uint256[]) public creatorCampaigns;
    mapping(address => uint256[]) public contributorCampaigns;

    uint256 public campaignCounter;
    uint256 public platformFeePercent = 250;
    uint256 private constant BASIS_POINTS = 10000;


    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goal,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    event RefundClaimed(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignCancelled(uint256 indexed campaignId);

    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Invalid campaign ID");
        require(campaigns[_campaignId].active, "Campaign not active");
        _;
    }

    modifier onlyCreator(uint256 _campaignId) {
        require(campaigns[_campaignId].creator == msg.sender, "Not campaign creator");
        _;
    }

    constructor() {}

    function createCampaign(
        string calldata _title,
        string calldata _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0 && _durationInDays <= 365, "Invalid duration");
        require(bytes(_title).length > 0, "Title cannot be empty");

        uint256 campaignId = campaignCounter++;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        campaigns[campaignId] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goal: _goal,
            raised: 0,
            deadline: deadline,
            withdrawn: false,
            active: true
        });

        creatorCampaigns[msg.sender].push(campaignId);

        emit CampaignCreated(campaignId, msg.sender, _title, _goal, deadline);

        return campaignId;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        validCampaign(_campaignId)
        nonReentrant
    {
        require(msg.value > 0, "Contribution must be greater than 0");

        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign ended");
        require(campaign.creator != msg.sender, "Cannot contribute to own campaign");


        uint256 currentRaised = campaign.raised;
        uint256 newRaised = currentRaised + msg.value;

        campaign.raised = newRaised;

        Contribution storage userContribution = contributions[_campaignId][msg.sender];
        if (userContribution.amount == 0) {
            contributorCampaigns[msg.sender].push(_campaignId);
        }
        userContribution.amount += msg.value;

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCreator(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(campaign.raised >= campaign.goal, "Goal not reached");
        require(!campaign.withdrawn, "Funds already withdrawn");

        campaign.withdrawn = true;


        uint256 totalRaised = campaign.raised;
        uint256 platformFee = (totalRaised * platformFeePercent) / BASIS_POINTS;
        uint256 creatorAmount = totalRaised - platformFee;


        if (platformFee > 0) {
            payable(owner()).transfer(platformFee);
        }


        campaign.creator.transfer(creatorAmount);

        emit CampaignWithdrawn(_campaignId, campaign.creator, creatorAmount);
    }

    function claimRefund(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(campaign.raised < campaign.goal, "Goal was reached");

        Contribution storage userContribution = contributions[_campaignId][msg.sender];
        require(userContribution.amount > 0, "No contribution found");
        require(!userContribution.refunded, "Already refunded");

        userContribution.refunded = true;
        uint256 refundAmount = userContribution.amount;

        payable(msg.sender).transfer(refundAmount);

        emit RefundClaimed(_campaignId, msg.sender, refundAmount);
    }

    function cancelCampaign(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.raised == 0, "Cannot cancel campaign with contributions");

        campaign.active = false;

        emit CampaignCancelled(_campaignId);
    }

    function getCampaignDetails(uint256 _campaignId)
        external
        view
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goal,
            uint256 raised,
            uint256 deadline,
            bool withdrawn,
            bool active,
            bool goalReached,
            bool isExpired
        )
    {
        require(_campaignId < campaignCounter, "Invalid campaign ID");

        Campaign storage campaign = campaigns[_campaignId];

        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.withdrawn,
            campaign.active,
            campaign.raised >= campaign.goal,
            block.timestamp >= campaign.deadline
        );
    }

    function getUserContribution(uint256 _campaignId, address _contributor)
        external
        view
        returns (uint256 amount, bool refunded)
    {
        Contribution storage contribution = contributions[_campaignId][_contributor];
        return (contribution.amount, contribution.refunded);
    }

    function getCreatorCampaigns(address _creator)
        external
        view
        returns (uint256[] memory)
    {
        return creatorCampaigns[_creator];
    }

    function getContributorCampaigns(address _contributor)
        external
        view
        returns (uint256[] memory)
    {
        return contributorCampaigns[_contributor];
    }

    function getActiveCampaignsCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < campaignCounter; i++) {
            if (campaigns[i].active && block.timestamp < campaigns[i].deadline) {
                count++;
            }
        }
    }

    function setPlatformFee(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 1000, "Fee cannot exceed 10%");
        platformFeePercent = _feePercent;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }
}
