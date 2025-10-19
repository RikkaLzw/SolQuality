
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrowdfundingPlatform is ReentrancyGuard, Ownable {
    enum CampaignStatus { Active, Successful, Failed, Cancelled }

    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        CampaignStatus status;
        uint256 contributorCount;
        bool fundsWithdrawn;
    }

    struct Contribution {
        uint256 amount;
        uint256 timestamp;
    }


    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Contribution)) public contributions;
    mapping(uint256 => address[]) private campaignContributors;
    mapping(address => uint256[]) private userCampaigns;

    uint256 public campaignCounter;
    uint256 public platformFeePercentage = 250;
    uint256 private constant PERCENTAGE_BASE = 10000;


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
        uint256 amount,
        uint256 totalRaised
    );

    event CampaignStatusChanged(
        uint256 indexed campaignId,
        CampaignStatus newStatus
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount,
        uint256 platformFee
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );


    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId > 0 && _campaignId <= campaignCounter, "Invalid campaign ID");
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(campaigns[_campaignId].creator == msg.sender, "Not campaign creator");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].status == CampaignStatus.Active, "Campaign not active");
        _;
    }

    constructor() {}

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _duration
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_goal > 0, "Goal must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        uint256 campaignId = ++campaignCounter;
        uint256 deadline = block.timestamp + _duration;

        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            title: _title,
            description: _description,
            goal: _goal,
            raised: 0,
            deadline: deadline,
            status: CampaignStatus.Active,
            contributorCount: 0,
            fundsWithdrawn: false
        });

        userCampaigns[msg.sender].push(campaignId);

        emit CampaignCreated(campaignId, msg.sender, _title, _goal, deadline);
        return campaignId;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        validCampaign(_campaignId)
        campaignActive(_campaignId)
        nonReentrant
    {
        require(msg.value > 0, "Contribution must be greater than 0");

        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign deadline passed");
        require(campaign.creator != msg.sender, "Creator cannot contribute to own campaign");


        Contribution storage existingContribution = contributions[_campaignId][msg.sender];
        bool isNewContributor = existingContribution.amount == 0;


        existingContribution.amount += msg.value;
        existingContribution.timestamp = block.timestamp;


        campaign.raised += msg.value;

        if (isNewContributor) {
            campaign.contributorCount++;
            campaignContributors[_campaignId].push(msg.sender);
        }


        if (campaign.raised >= campaign.goal && campaign.status == CampaignStatus.Active) {
            campaign.status = CampaignStatus.Successful;
            emit CampaignStatusChanged(_campaignId, CampaignStatus.Successful);
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value, campaign.raised);
    }

    function withdrawFunds(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.status == CampaignStatus.Successful, "Campaign not successful");
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");
        require(campaign.raised > 0, "No funds to withdraw");

        campaign.fundsWithdrawn = true;

        uint256 platformFee = (campaign.raised * platformFeePercentage) / PERCENTAGE_BASE;
        uint256 creatorAmount = campaign.raised - platformFee;


        (bool success, ) = payable(campaign.creator).call{value: creatorAmount}("");
        require(success, "Transfer to creator failed");


        if (platformFee > 0) {
            (bool feeSuccess, ) = payable(owner()).call{value: platformFee}("");
            require(feeSuccess, "Platform fee transfer failed");
        }

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount, platformFee);
    }

    function requestRefund(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(
            campaign.status == CampaignStatus.Failed ||
            (campaign.status == CampaignStatus.Active && block.timestamp >= campaign.deadline),
            "Refund not available"
        );

        Contribution storage contribution = contributions[_campaignId][msg.sender];
        require(contribution.amount > 0, "No contribution found");

        uint256 refundAmount = contribution.amount;
        contribution.amount = 0;


        if (campaign.status == CampaignStatus.Active && block.timestamp >= campaign.deadline) {
            if (campaign.raised < campaign.goal) {
                campaign.status = CampaignStatus.Failed;
                emit CampaignStatusChanged(_campaignId, CampaignStatus.Failed);
            }
        }

        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_campaignId, msg.sender, refundAmount);
    }

    function cancelCampaign(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.status == CampaignStatus.Active, "Campaign not active");
        require(campaign.raised == 0, "Cannot cancel campaign with contributions");

        campaign.status = CampaignStatus.Cancelled;
        emit CampaignStatusChanged(_campaignId, CampaignStatus.Cancelled);
    }


    function getCampaign(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (Campaign memory)
    {
        return campaigns[_campaignId];
    }

    function getCampaignContributors(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (address[] memory)
    {
        return campaignContributors[_campaignId];
    }

    function getUserContribution(uint256 _campaignId, address _user)
        external
        view
        validCampaign(_campaignId)
        returns (uint256, uint256)
    {
        Contribution memory contribution = contributions[_campaignId][_user];
        return (contribution.amount, contribution.timestamp);
    }

    function getUserCampaigns(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userCampaigns[_user];
    }

    function isCampaignExpired(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (bool)
    {
        return block.timestamp >= campaigns[_campaignId].deadline;
    }

    function getCampaignProgress(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (uint256 raised, uint256 goal, uint256 percentage)
    {
        Campaign storage campaign = campaigns[_campaignId];
        raised = campaign.raised;
        goal = campaign.goal;
        percentage = goal > 0 ? (raised * 100) / goal : 0;
    }


    function setPlatformFee(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 1000, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Emergency withdrawal failed");
    }

    receive() external payable {
        revert("Direct payments not accepted");
    }

    fallback() external {
        revert("Function not found");
    }
}
