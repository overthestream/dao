// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

// interface for FakeNFTMarketplace contract
interface IFakeNFTMarketplace {
    //@dev getPrice() returns price of NFT from FakeNFTMarketplace
    // @retrun returns price in Wei for NFT
    function getPrice() external view returns (uint256);

    // @dev available() returns whether or not the given _tokenId has already been purchased
    // returns bool - true if available, false if not
    function available(uint256 _tokenId) external view returns (bool);

    // @dev purchase() purchases an NFT from FakeNFTMarketplace
    // @param _tokenId - the token Id to purchase
    function purchase(uint256 _tokenId) external payable;
}

/**
minimal interface for CryptoDevsNFT containing only two functions that are needed here 
*/
interface ICryptoDevsNFT {
    // @dev returns uint number of NFTs owned by address
    // @param owner - address to fetch number of NFTs for
    function balanceOf(address owner) external view returns (uint256);

    //@dev tokenOfOwnerByIndex returns tokenId at given index for owner
    // @param owner - address to fetch TokenID for
    // @param index - indec of NFT in owned tokens array to fetch
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);
}

contract CryptoDevsDAO is Ownable {
    // struct Proposal containing all relevant info
    struct Proposal {
        //nftTokenId - token id of NFT to purchase if proposal passes
        uint256 nftTokenId;
        // deadline - UNIX timestamp until which this proposal is active - proposal can be executed after the deadline has exceeded
        uint256 deadline;
        // yayVotes - number of yay votes for proposal
        uint256 yayVotes;
        // nayVotes
        uint256 nayVotes;
        // executed - whether or not this proposal has been executed or not. cannot be executed before the deadline
        bool executed;
        // voters - mapping of CryptoDevsNFT tokenIDs to booleans indicating whether that NFT has already been used to cast a vote or not
        mapping(uint256 => bool) voters;
    }

    // mapping from Proposal ID to proposals to hold created proposals
    mapping(uint256 => Proposal) public proposals;
    // number of proposals created
    uint256 public numProposals;

    //initialize variables for contracts from interfaces
    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    //payable constructor witch initializes the contract
    // instances for FakeNFTMarketplace and CryptoDevsNFT
    // payable allows this contract to accept ETH deposit when its being deployed
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    // modifier which only allows a function to be called by someones who owns at least 1 CyptoDevs NFT
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT A DAO MEMBER");
        _;
    }

    // @dev createProposal allows a CryptoDevs NFT holder to create a new proposal in the DAO
    // @param _nftTokenId - token ID of the NFT to be purchased from the fake marketplace if proposal is passed
    // @return returns the proposal index for the newly created proposal
    function createProposal(uint256 _nftTokenId)
        external
        nftHolderOnly
        returns (uint256)
    {
        require(nftMarketplace.available(_nftTokenId), "NFT NOT FOR SALE");
        Proposal storage proposal = proposals[numProposals]; // save to blockchain storage
        proposal.nftTokenId = _nftTokenId;
        // set the proposals voting deadline to be (current time + 5 min)
        proposal.deadline = block.timestamp + 5 minutes;

        numProposals++;

        return numProposals - 1;
    }

    // modifer for function to only called if given proposal is active
    modifier activeProposalOnly(uint256 proposalIndex) {
        //modifer takes a parameter
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "DEADLINE EXCEEDED"
        );
        _;
    }

    // enum named Vote containing possible options for a vote
    //YAY = 0, NAY = 1
    enum Vote {
        YAY,
        NAY
    }

    function VoteOnProposal(uint256 proposalIndex, Vote vote)
        external
        nftHolderOnly
        activeProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        //calculate num of NFTs that havent been used for voting on this proposal
        for (uint256 i = 0; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "ALREADY VOTED");

        // musty cast all votes to one choice
        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    //modifier which only allows function to be called if given proposal's deadline HAS been exceeded and not yet executed
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp,
            "Deadline not exceeed"
        );
        require(
            proposals[proposalIndex].executed == false,
            "proposal already executed"
        );
        _;
    }

    //@dev allows any CryptoDevsNFT holder to execute a proposal after its deadline
    // @param proposalIndex - index of proposal in proposals array
    function executeProposal(uint256 proposalIndex)
        external
        nftHolderOnly
        inactiveProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

        // if proposal has more YAY than NAY votes, purchase NFT from fake marketplace
        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "not enough funds");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    //withdraw from contract - only owner
    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // The following two functions allow the contract to accept ETH deposits
    // directly from a wallet without calling a function
    receive() external payable {}

    fallback() external payable {}
}
