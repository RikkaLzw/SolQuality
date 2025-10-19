
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool completed;
        bool withdrawn;
    }

    struct Contribution {
        address contributor;
        uint256 amount;
        uint256 timestamp;
        bool refunded;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => Contribution[]) public campaignContributions;
    mapping(address => uint256[]) public userCampaigns;
    mapping(address => uint256[]) public userContributions;

    uint256 public campaignCounter;
    uint256 public platformFee = 25;
    address public owner;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event FundsWithdrawn(uint256 indexed campaignId, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    constructor() {
        owner = msg.sender;
    }




    function createCampaignAndSetupRewards(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _durationDays,
        bool _autoWithdraw,
        uint256 _minContribution,
        address _beneficiary
    ) public {
        require(_goal > 0, "Goal must be positive");
        require(_durationDays > 0, "Duration must be positive");
        require(bytes(_title).length > 0, "Title required");

        campaignCounter++;
        uint256 campaignId = campaignCounter;


        campaigns[campaignId] = Campaign({
            creator: _beneficiary != address(0) ? _beneficiary : msg.sender,
            title: _title,
            description: _description,
            goal: _goal,
            raised: 0,
            deadline: block.timestamp + (_durationDays * 1 days),
            completed: false,
            withdrawn: false
        });


        userCampaigns[msg.sender].push(campaignId);


        if (_autoWithdraw) {

        }


        if (_minContribution > 0) {

        }

        emit CampaignCreated(campaignId, campaigns[campaignId].creator);
    }



    function processContributionWithValidation(uint256 _campaignId) public payable {
        require(_campaignId > 0 && _campaignId <= campaignCounter, "Invalid campaign");
        require(msg.value > 0, "Must send ETH");

        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign ended");
        require(!campaign.completed, "Campaign completed");


        if (campaign.raised + msg.value >= campaign.goal) {
            if (campaign.raised < campaign.goal) {

                uint256 excessAmount = (campaign.raised + msg.value) - campaign.goal;
                if (excessAmount > 0) {

                    uint256 actualContribution = msg.value - excessAmount;
                    if (actualContribution > 0) {

                        contributions[_campaignId][msg.sender] += actualContribution;
                        campaign.raised += actualContribution;

                        campaignContributions[_campaignId].push(Contribution({
                            contributor: msg.sender,
                            amount: actualContribution,
                            timestamp: block.timestamp,
                            refunded: false
                        }));

                        userContributions[msg.sender].push(_campaignId);


                        campaign.completed = true;


                        if (excessAmount > 0) {
                            payable(msg.sender).transfer(excessAmount);
                        }

                        emit ContributionMade(_campaignId, msg.sender, actualContribution);
                    }
                } else {

                    contributions[_campaignId][msg.sender] += msg.value;
                    campaign.raised += msg.value;
                    campaign.completed = true;

                    campaignContributions[_campaignId].push(Contribution({
                        contributor: msg.sender,
                        amount: msg.value,
                        timestamp: block.timestamp,
                        refunded: false
                    }));

                    userContributions[msg.sender].push(_campaignId);
                    emit ContributionMade(_campaignId, msg.sender, msg.value);
                }
            }
        } else {

            contributions[_campaignId][msg.sender] += msg.value;
            campaign.raised += msg.value;

            campaignContributions[_campaignId].push(Contribution({
                contributor: msg.sender,
                amount: msg.value,
                timestamp: block.timestamp,
                refunded: false
            }));

            userContributions[msg.sender].push(_campaignId);
            emit ContributionMade(_campaignId, msg.sender, msg.value);
        }
    }


    function calculateFeeAndTransfer(uint256 _campaignId, uint256 _amount) public returns (bool, uint256) {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only creator");
        require(campaign.completed, "Campaign not completed");
        require(!campaign.withdrawn, "Already withdrawn");
        require(_amount <= campaign.raised, "Insufficient funds");

        uint256 fee = (_amount * platformFee) / 1000;
        uint256 netAmount = _amount - fee;

        campaign.withdrawn = true;

        payable(owner).transfer(fee);
        payable(campaign.creator).transfer(netAmount);

        emit FundsWithdrawn(_campaignId, netAmount);
        return (true, netAmount);
    }

    function withdrawFunds(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only creator can withdraw");
        require(campaign.completed, "Campaign not completed");
        require(!campaign.withdrawn, "Funds already withdrawn");

        calculateFeeAndTransfer(_campaignId, campaign.raised);
    }


    function processRefunds(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp > campaign.deadline, "Campaign still active");
        require(!campaign.completed, "Campaign was successful");

        Contribution[] storage contribs = campaignContributions[_campaignId];

        for (uint256 i = 0; i < contribs.length; i++) {
            if (!contribs[i].refunded) {
                if (contribs[i].amount > 0) {
                    if (contribs[i].contributor != address(0)) {

                        uint256 refundAmount = contribs[i].amount;
                        if (refundAmount <= address(this).balance) {
                            contribs[i].refunded = true;
                            contributions[_campaignId][contribs[i].contributor] = 0;

                            payable(contribs[i].contributor).transfer(refundAmount);
                            emit RefundIssued(_campaignId, contribs[i].contributor, refundAmount);
                        }
                    }
                }
            }
        }
    }

    function getCampaignDetails(uint256 _campaignId) public view returns (
        address creator,
        string memory title,
        uint256 goal,
        uint256 raised,
        uint256 deadline,
        bool completed
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.completed
        );
    }

    function getUserCampaigns(address _user) public view returns (uint256[] memory) {
        return userCampaigns[_user];
    }

    function getUserContributions(address _user) public view returns (uint256[] memory) {
        return userContributions[_user];
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
