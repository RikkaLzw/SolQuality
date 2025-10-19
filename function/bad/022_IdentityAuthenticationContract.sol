
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct UserProfile {
        string username;
        string email;
        bytes32 passwordHash;
        bool isVerified;
        uint256 registrationTime;
        uint256 lastLoginTime;
        string[] roles;
        mapping(string => string) metadata;
    }

    mapping(address => UserProfile) private users;
    mapping(string => address) private usernameToAddress;
    mapping(string => address) private emailToAddress;
    address[] private userAddresses;

    event UserRegistered(address indexed user, string username);
    event UserLoggedIn(address indexed user, uint256 timestamp);
    event UserVerified(address indexed user);





    function registerAndVerifyUserWithCompleteProfile(
        string memory username,
        string memory email,
        string memory password,
        string memory firstName,
        string memory lastName,
        string memory phoneNumber,
        string memory country
    ) public {
        bytes32 passwordHash = keccak256(abi.encodePacked(password));

        if (bytes(username).length > 0) {
            if (usernameToAddress[username] == address(0)) {
                if (bytes(email).length > 0) {
                    if (emailToAddress[email] == address(0)) {
                        if (bytes(password).length >= 8) {
                            users[msg.sender].username = username;
                            users[msg.sender].email = email;
                            users[msg.sender].passwordHash = passwordHash;
                            users[msg.sender].registrationTime = block.timestamp;
                            users[msg.sender].lastLoginTime = block.timestamp;

                            usernameToAddress[username] = msg.sender;
                            emailToAddress[email] = msg.sender;
                            userAddresses.push(msg.sender);


                            users[msg.sender].metadata["firstName"] = firstName;
                            users[msg.sender].metadata["lastName"] = lastName;
                            users[msg.sender].metadata["phoneNumber"] = phoneNumber;
                            users[msg.sender].metadata["country"] = country;


                            if (bytes(firstName).length > 0 && bytes(lastName).length > 0) {
                                if (bytes(phoneNumber).length > 0) {
                                    users[msg.sender].isVerified = true;
                                    emit UserVerified(msg.sender);
                                }
                            }


                            users[msg.sender].roles.push("user");
                            if (keccak256(abi.encodePacked(country)) == keccak256(abi.encodePacked("VIP"))) {
                                users[msg.sender].roles.push("premium");
                            }

                            emit UserRegistered(msg.sender, username);
                            emit UserLoggedIn(msg.sender, block.timestamp);
                        }
                    }
                }
            }
        }
    }


    function validatePasswordStrength(string memory password) public pure returns (bool) {
        return bytes(password).length >= 8;
    }


    function generatePasswordHash(string memory password) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(password));
    }




    function loginAndUpdateProfileAndCheckPermissions(
        string memory username,
        string memory password,
        string memory newEmail,
        string memory newPhone
    ) public returns (bool, uint256, string memory) {
        address userAddr = usernameToAddress[username];

        if (userAddr != address(0)) {
            if (userAddr == msg.sender) {
                bytes32 inputHash = keccak256(abi.encodePacked(password));
                if (users[msg.sender].passwordHash == inputHash) {
                    users[msg.sender].lastLoginTime = block.timestamp;


                    if (bytes(newEmail).length > 0) {
                        if (emailToAddress[newEmail] == address(0)) {
                            emailToAddress[users[msg.sender].email] = address(0);
                            users[msg.sender].email = newEmail;
                            emailToAddress[newEmail] = msg.sender;
                        }
                    }

                    if (bytes(newPhone).length > 0) {
                        users[msg.sender].metadata["phoneNumber"] = newPhone;
                    }


                    string memory permission = "basic";
                    for (uint i = 0; i < users[msg.sender].roles.length; i++) {
                        if (keccak256(abi.encodePacked(users[msg.sender].roles[i])) == keccak256(abi.encodePacked("premium"))) {
                            permission = "premium";
                            break;
                        }
                    }

                    emit UserLoggedIn(msg.sender, block.timestamp);
                    return (true, users[msg.sender].lastLoginTime, permission);
                }
            }
        }
        return (false, 0, "none");
    }



    function updateUserCompleteProfile(
        string memory newUsername,
        string memory newEmail,
        string memory firstName,
        string memory lastName,
        string memory phoneNumber,
        string memory country,
        string memory newRole
    ) public {
        require(bytes(users[msg.sender].username).length > 0, "User not registered");

        if (bytes(newUsername).length > 0) {
            if (usernameToAddress[newUsername] == address(0)) {
                usernameToAddress[users[msg.sender].username] = address(0);
                users[msg.sender].username = newUsername;
                usernameToAddress[newUsername] = msg.sender;
            }
        }

        if (bytes(newEmail).length > 0) {
            if (emailToAddress[newEmail] == address(0)) {
                emailToAddress[users[msg.sender].email] = address(0);
                users[msg.sender].email = newEmail;
                emailToAddress[newEmail] = msg.sender;
            }
        }

        users[msg.sender].metadata["firstName"] = firstName;
        users[msg.sender].metadata["lastName"] = lastName;
        users[msg.sender].metadata["phoneNumber"] = phoneNumber;
        users[msg.sender].metadata["country"] = country;

        if (bytes(newRole).length > 0) {
            users[msg.sender].roles.push(newRole);
        }
    }

    function getUserInfo(address user) public view returns (string memory, string memory, bool, uint256) {
        return (
            users[user].username,
            users[user].email,
            users[user].isVerified,
            users[user].registrationTime
        );
    }

    function isUserRegistered(address user) public view returns (bool) {
        return bytes(users[user].username).length > 0;
    }

    function getUserMetadata(address user, string memory key) public view returns (string memory) {
        return users[user].metadata[key];
    }

    function getUserRoles(address user) public view returns (string[] memory) {
        return users[user].roles;
    }

    function getTotalUsers() public view returns (uint256) {
        return userAddresses.length;
    }
}
