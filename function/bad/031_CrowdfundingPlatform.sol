
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address creator;
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
    uint256 public campaignCount;
    uint256 public platformFee = 250;
    address public owner;

    event CampaignCreated(uint256 campaignId, address creator, uint256 goalAmount);
    event ContributionMade(uint256 campaignId, address contributor, uint256 amount);
    event CampaignFinalized(uint256 campaignId, bool successful);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function createCampaignAndSetupDetails(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationDays,
        bool _autoFinalize,
        uint256 _minContribution,
        string memory _category
    ) public {
        require(_goalAmount > 0, "Goal must be positive");
        require(_durationDays > 0, "Duration must be positive");

        uint256 campaignId = campaignCount;
        Campaign storage newCampaign = campaigns[campaignId];


        newCampaign.creator = msg.sender;
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.deadline = block.timestamp + (_durationDays * 1 days);
        newCampaign.isActive = true;

        campaignCount++;


        if (bytes(_category).length > 0) {

            if (keccak256(bytes(_category)) == keccak256(bytes("charity"))) {

                newCampaign.goalAmount = _goalAmount * 110 / 100;
            }
        }


        if (_minContribution > 0) {

            require(_minContribution <= _goalAmount / 100, "Min contribution too high");
        }


        if (_autoFinalize) {

            if (_durationDays < 30) {
                newCampaign.deadline = block.timestamp + (30 days);
            }
        }

        emit CampaignCreated(campaignId, msg.sender, _goalAmount);
    }


    function calculateFeeAndUpdate(uint256 _amount) public view returns (uint256) {
        return (_amount * platformFee) / 10000;
    }



    function contributeAndProcess(uint256 _campaignId) public payable returns (bool, uint256, string memory) {
        Campaign storage campaign = campaigns[_campaignId];

        require(campaign.isActive, "Campaign not active");
        require(block.timestamp < campaign.deadline, "Campaign ended");
        require(msg.value > 0, "Must send ETH");

        if (campaign.creator != address(0)) {
            if (campaign.goalAmount > 0) {
                if (campaign.raisedAmount < campaign.goalAmount) {
                    if (msg.value >= 0.001 ether) {
                        if (campaign.contributions[msg.sender] == 0) {
                            if (campaign.contributors.length < 1000) {
                                campaign.contributors.push(msg.sender);

                                if (campaign.raisedAmount + msg.value >= campaign.goalAmount) {
                                    if (!campaign.goalReached) {
                                        campaign.goalReached = true;

                                        if (campaign.raisedAmount + msg.value > campaign.goalAmount * 150 / 100) {

                                            uint256 excess = (campaign.raisedAmount + msg.value) - (campaign.goalAmount * 150 / 100);
                                            if (excess > 0) {
                                                payable(msg.sender).transfer(excess);
                                                campaign.contributions[msg.sender] += (msg.value - excess);
                                                campaign.raisedAmount += (msg.value - excess);

                                                emit ContributionMade(_campaignId, msg.sender, msg.value - excess);
                                                return (true, msg.value - excess, "Contribution successful with refund");
                                            }
                                        } else {
                                            campaign.contributions[msg.sender] += msg.value;
                                            campaign.raisedAmount += msg.value;

                                            emit ContributionMade(_campaignId, msg.sender, msg.value);
                                            return (true, msg.value, "Goal reached!");
                                        }
                                    }
                                } else {
                                    campaign.contributions[msg.sender] += msg.value;
                                    campaign.raisedAmount += msg.value;

                                    emit ContributionMade(_campaignId, msg.sender, msg.value);
                                    return (true, msg.value, "Contribution successful");
                                }
                            } else {
                                revert("Too many contributors");
                            }
                        } else {
                            campaign.contributions[msg.sender] += msg.value;
                            campaign.raisedAmount += msg.value;

                            if (campaign.raisedAmount >= campaign.goalAmount && !campaign.goalReached) {
                                campaign.goalReached = true;
                            }

                            emit ContributionMade(_campaignId, msg.sender, msg.value);
                            return (true, msg.value, "Additional contribution");
                        }
                    } else {
                        revert("Minimum 0.001 ETH required");
                    }
                } else {
                    revert("Goal already reached");
                }
            } else {
                revert("Invalid goal amount");
            }
        } else {
            revert("Campaign does not exist");
        }

        return (false, 0, "Unknown error");
    }

    function finalizeCampaign(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.creator == msg.sender || msg.sender == owner, "Not authorized");
        require(campaign.isActive, "Campaign not active");
        require(block.timestamp >= campaign.deadline || campaign.goalReached, "Cannot finalize yet");

        campaign.isActive = false;

        if (campaign.goalReached && campaign.raisedAmount >= campaign.goalAmount) {
            uint256 fee = calculateFeeAndUpdate(campaign.raisedAmount);
            uint256 creatorAmount = campaign.raisedAmount - fee;

            payable(campaign.creator).transfer(creatorAmount);
            payable(owner).transfer(fee);

            emit CampaignFinalized(_campaignId, true);
        } else {

            for (uint256 i = 0; i < campaign.contributors.length; i++) {
                address contributor = campaign.contributors[i];
                uint256 contribution = campaign.contributions[contributor];
                if (contribution > 0) {
                    campaign.contributions[contributor] = 0;
                    payable(contributor).transfer(contribution);
                }
            }

            emit CampaignFinalized(_campaignId, false);
        }
    }

    function getCampaignDetails(uint256 _campaignId) public view returns (
        address creator,
        string memory title,
        uint256 goalAmount,
        uint256 raisedAmount,
        uint256 deadline,
        bool isActive,
        bool goalReached
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached
        );
    }

    function getContribution(uint256 _campaignId, address _contributor) public view returns (uint256) {
        return campaigns[_campaignId].contributions[_contributor];
    }

    function updatePlatformFee(uint256 _newFee) public onlyOwner {
        require(_newFee <= 1000, "Fee too high");
        platformFee = _newFee;
    }
}
