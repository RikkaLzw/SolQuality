
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract CrowdfundingPlatform is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant PLATFORM_FEE_RATE = 250;
    uint256 public constant MIN_FUNDING_GOAL = 0.1 ether;
    uint256 public constant MAX_FUNDING_DURATION = 365 days;
    uint256 public constant MIN_FUNDING_DURATION = 1 days;


    enum CampaignStatus {
        Active,
        Successful,
        Failed,
        Cancelled,
        Withdrawn
    }


    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        CampaignStatus status;
        bool exists;
    }

    struct Contribution {
        uint256 amount;
        uint256 timestamp;
        bool refunded;
    }


    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Contribution)) public contributions;
    mapping(uint256 => address[]) public campaignContributors;

    uint256 public nextCampaignId;
    uint256 public totalCampaigns;
    uint256 public platformBalance;


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

    event CampaignStatusChanged(
        uint256 indexed campaignId,
        CampaignStatus newStatus
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );


    modifier validCampaign(uint256 _campaignId) {
        require(campaigns[_campaignId].exists, "Campaign does not exist");
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(
            campaigns[_campaignId].creator == msg.sender,
            "Only campaign creator can perform this action"
        );
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(
            campaigns[_campaignId].status == CampaignStatus.Active,
            "Campaign is not active"
        );
        require(
            block.timestamp <= campaigns[_campaignId].deadline,
            "Campaign deadline has passed"
        );
        _;
    }

    modifier campaignEnded(uint256 _campaignId) {
        require(
            block.timestamp > campaigns[_campaignId].deadline,
            "Campaign is still active"
        );
        _;
    }

    constructor() {}


    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _duration
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_goalAmount >= MIN_FUNDING_GOAL, "Goal amount too low");
        require(
            _duration >= MIN_FUNDING_DURATION && _duration <= MAX_FUNDING_DURATION,
            "Invalid campaign duration"
        );

        uint256 campaignId = nextCampaignId++;
        uint256 deadline = block.timestamp.add(_duration);

        campaigns[campaignId] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            status: CampaignStatus.Active,
            exists: true
        });

        totalCampaigns++;

        emit CampaignCreated(campaignId, msg.sender, _title, _goalAmount, deadline);
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
        require(
            msg.sender != campaigns[_campaignId].creator,
            "Creator cannot contribute to own campaign"
        );

        Campaign storage campaign = campaigns[_campaignId];


        if (contributions[_campaignId][msg.sender].amount == 0) {
            campaignContributors[_campaignId].push(msg.sender);
        }

        contributions[_campaignId][msg.sender].amount = contributions[_campaignId][msg.sender]
            .amount
            .add(msg.value);
        contributions[_campaignId][msg.sender].timestamp = block.timestamp;

        campaign.raisedAmount = campaign.raisedAmount.add(msg.value);

        emit ContributionMade(_campaignId, msg.sender, msg.value);


        if (campaign.raisedAmount >= campaign.goalAmount) {
            _updateCampaignStatus(_campaignId, CampaignStatus.Successful);
        }
    }


    function withdrawFunds(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(
            campaign.status == CampaignStatus.Successful ||
            (block.timestamp > campaign.deadline && campaign.raisedAmount >= campaign.goalAmount),
            "Campaign not successful or not ended"
        );
        require(campaign.raisedAmount > 0, "No funds to withdraw");

        uint256 totalAmount = campaign.raisedAmount;
        uint256 platformFee = totalAmount.mul(PLATFORM_FEE_RATE).div(10000);
        uint256 creatorAmount = totalAmount.sub(platformFee);

        campaign.raisedAmount = 0;
        platformBalance = platformBalance.add(platformFee);

        _updateCampaignStatus(_campaignId, CampaignStatus.Withdrawn);

        (bool success, ) = campaign.creator.call{value: creatorAmount}("");
        require(success, "Transfer to creator failed");

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
    }


    function requestRefund(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        campaignEnded(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(
            campaign.raisedAmount < campaign.goalAmount,
            "Campaign was successful, no refund available"
        );

        Contribution storage contribution = contributions[_campaignId][msg.sender];
        require(contribution.amount > 0, "No contribution found");
        require(!contribution.refunded, "Already refunded");

        uint256 refundAmount = contribution.amount;
        contribution.refunded = true;
        campaign.raisedAmount = campaign.raisedAmount.sub(refundAmount);

        if (campaign.status != CampaignStatus.Failed) {
            _updateCampaignStatus(_campaignId, CampaignStatus.Failed);
        }

        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_campaignId, msg.sender, refundAmount);
    }


    function cancelCampaign(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
        campaignActive(_campaignId)
    {
        _updateCampaignStatus(_campaignId, CampaignStatus.Cancelled);
    }


    function finalizeCampaign(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        campaignEnded(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.status == CampaignStatus.Active, "Campaign already finalized");

        if (campaign.raisedAmount >= campaign.goalAmount) {
            _updateCampaignStatus(_campaignId, CampaignStatus.Successful);
        } else {
            _updateCampaignStatus(_campaignId, CampaignStatus.Failed);
        }
    }


    function withdrawPlatformFees() external onlyOwner nonReentrant {
        require(platformBalance > 0, "No platform fees to withdraw");

        uint256 amount = platformBalance;
        platformBalance = 0;

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Platform fee withdrawal failed");
    }


    function getCampaign(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            CampaignStatus status
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.status
        );
    }

    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        returns (uint256 amount, uint256 timestamp, bool refunded)
    {
        Contribution storage contribution = contributions[_campaignId][_contributor];
        return (contribution.amount, contribution.timestamp, contribution.refunded);
    }

    function getCampaignContributors(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (address[] memory)
    {
        return campaignContributors[_campaignId];
    }

    function getCampaignContributorsCount(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (uint256)
    {
        return campaignContributors[_campaignId].length;
    }


    function _updateCampaignStatus(uint256 _campaignId, CampaignStatus _newStatus) internal {
        campaigns[_campaignId].status = _newStatus;
        emit CampaignStatusChanged(_campaignId, _newStatus);
    }
}
