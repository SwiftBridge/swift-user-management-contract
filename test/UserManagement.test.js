const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UserManagement", function () {
    let UserManagement;
    let userManagement;
    let owner, addr1, addr2, addr3;

    const REGISTRATION_FEE = ethers.parseEther("0.000003");
    const VERIFICATION_FEE = ethers.parseEther("0.000003");

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();
        UserManagement = await ethers.getContractFactory("UserManagement");
        userManagement = await UserManagement.deploy();
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await userManagement.owner()).to.equal(owner.address);
        });

        it("Should make owner an admin", async function () {
            expect(await userManagement.admins(owner.address)).to.be.true;
        });

        it("Should initialize counters correctly", async function () {
            expect(await userManagement.getTotalUserCount()).to.equal(0);
        });
    });

    describe("Registration", function () {
        it("Should register a new user successfully", async function () {
            await expect(userManagement.connect(addr1).registerUser("alice", "Bio", "avatar.png", { value: REGISTRATION_FEE }))
                .to.emit(userManagement, "UserRegistered")
                .withArgs(addr1.address, "alice", await ethers.provider.getBlock("latest").then(b => b.timestamp + 1)); // timestamp check is approximate

            const profile = await userManagement.getUserProfile(addr1.address);
            expect(profile.username).to.equal("alice");
            expect(profile.isActive).to.be.true;
        });

        it("Should fail if fee is insufficient", async function () {
            await expect(userManagement.connect(addr1).registerUser("alice", "Bio", "url", { value: 0 }))
                .to.be.revertedWithCustomError(userManagement, "InsufficientFee");
        });

        it("Should fail if username is too short", async function () {
            await expect(userManagement.connect(addr1).registerUser("ab", "Bio", "url", { value: REGISTRATION_FEE }))
                .to.be.revertedWithCustomError(userManagement, "UsernameTooShort");
        });

        it("Should fail if username is too long", async function () {
            await expect(userManagement.connect(addr1).registerUser("a".repeat(21), "Bio", "url", { value: REGISTRATION_FEE }))
                .to.be.revertedWithCustomError(userManagement, "UsernameTooLong");
        });

        it("Should fail if username is already taken", async function () {
            await userManagement.connect(addr1).registerUser("alice", "Bio", "url", { value: REGISTRATION_FEE });
            await expect(userManagement.connect(addr2).registerUser("alice", "Bio", "url", { value: REGISTRATION_FEE }))
                .to.be.revertedWithCustomError(userManagement, "UsernameTaken");
        });

        it("Should fail if user is already registered", async function () {
            await userManagement.connect(addr1).registerUser("alice", "Bio", "url", { value: REGISTRATION_FEE });
            await expect(userManagement.connect(addr1).registerUser("alice2", "Bio", "url", { value: REGISTRATION_FEE }))
                .to.be.revertedWithCustomError(userManagement, "UserAlreadyRegistered");
        });
    });

    describe("Profile Updates", function () {
        beforeEach(async function () {
            await userManagement.connect(addr1).registerUser("alice", "Bio", "url", { value: REGISTRATION_FEE });
        });

        it("Should update profile successfully", async function () {
            await userManagement.connect(addr1).updateProfile("alice2", "New Bio", "new.png", "email", "twitter", "github", "website");

            const profile = await userManagement.getUserProfile(addr1.address);
            expect(profile.username).to.equal("alice2");
            expect(profile.bio).to.equal("New Bio");
        });

        it("Should fail update if user is banned", async function () {
            await userManagement.banUser(addr1.address, "Bad behavior");
            await expect(userManagement.connect(addr1).updateProfile("alice", "Bio", "url", "", "", "", ""))
                .to.be.revertedWithCustomError(userManagement, "UserBanned");
        });
    });

    describe("Verification", function () {
        beforeEach(async function () {
            await userManagement.connect(addr1).registerUser("alice", "Bio", "url", { value: REGISTRATION_FEE });
        });

        it("Should submit verification request", async function () {
            await userManagement.connect(addr1).submitVerificationRequest("data", "type", { value: VERIFICATION_FEE });
            const request = await userManagement.verificationRequests(1);
            expect(request.user).to.equal(addr1.address);
        });

        it("Should process verification request (approve)", async function () {
            await userManagement.connect(addr1).submitVerificationRequest("data", "type", { value: VERIFICATION_FEE });

            await expect(userManagement.processVerificationRequest(1, true))
                .to.emit(userManagement, "UserVerified")
                .withArgs(addr1.address, true);

            const profile = await userManagement.getUserProfile(addr1.address);
            expect(profile.isVerified).to.be.true;
        });

        it("Should fail processing if not admin", async function () {
            await userManagement.connect(addr1).submitVerificationRequest("data", "type", { value: VERIFICATION_FEE });
            await expect(userManagement.connect(addr2).processVerificationRequest(1, true))
                .to.be.revertedWithCustomError(userManagement, "NotAdmin");
        });
    });

    describe("Admin Actions", function () {
        beforeEach(async function () {
            await userManagement.connect(addr1).registerUser("alice", "Bio", "url", { value: REGISTRATION_FEE });
        });

        it("Should ban user", async function () {
            await userManagement.banUser(addr1.address, "Spam");
            const profile = await userManagement.getUserProfile(addr1.address);
            expect(profile.isBanned).to.be.true;
            expect(profile.isActive).to.be.false;
        });

        it("Should unban user", async function () {
            await userManagement.banUser(addr1.address, "Spam");
            await userManagement.unbanUser(addr1.address);
            const profile = await userManagement.getUserProfile(addr1.address);
            expect(profile.isBanned).to.be.false;
            expect(profile.isActive).to.be.true;
        });

        it("Should fail to ban owner", async function () {
            // Owner checks require them to be registered first based on logic? 
            // No, banUser checks: registeredAt > 0.
            // Let's register owner first to test this specific constraint cleanly.
            await userManagement.registerUser("owner", "Bio", "url", { value: REGISTRATION_FEE });
            await expect(userManagement.banUser(owner.address, "reason"))
                .to.be.revertedWithCustomError(userManagement, "CannotBanOwner");
        });
    });

    describe("Configuration", function () {
        it("Should update registration fee", async function () {
            const newFee = ethers.parseEther("0.1");
            await userManagement.setRegistrationFee(newFee);
            expect(await userManagement.registrationFee()).to.equal(newFee);
        });

        it("Should update verification fee", async function () {
            const newFee = ethers.parseEther("0.1");
            await userManagement.setVerificationFee(newFee);
            expect(await userManagement.verificationFee()).to.equal(newFee);
        });
    });
});
