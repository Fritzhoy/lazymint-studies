// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
//import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract LazyMint is ERC721, ERC721Royalty, AccessControl, ReentrancyGuard {
   
   using Strings for uint256; 
   
    enum SALE_STATUS {
        OFF,
        AUCTION
    }
    
    //OPERATOR = 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    SALE_STATUS public saleStatus;
    string baseTokenURI;

    uint256 private mintCount;
    uint256 public constant MAX_NFT = 300; //Max supply of NFTs
    uint256 public constant PRESALE_PRICE = 50000000000000000; //0,05Eth

    uint128 public constant PRESALE_NFT = 2;
    uint256 public auctionStartAt; // Auction timer for public mint
    //uint256 public constant PRICE_DEDUCTION_PERCENTAGE = 100000000000000000; // 0.1 Ether
    uint256 public constant STARTING_PRICE = 100000000000000000; // 0,1 Etheruint256 public preSalePrice;

    //the uri of the not revealed picture
    string public notRevealedUri;    

    /*are the NFT's revealed (viewable)? If true users can see the NFTs. 
    if false everyone sees a reveal picture*/
    bool public revealed = false;    

    mapping(address => uint256) public preSaleMintCount;
    mapping(address => uint256) public SaleMintCount;

    mapping(address => uint256) public lastMintBlock;

    event Minted(address OwnerNFT, uint256 totalMinted);

    constructor(string memory baseURI,  address _client, uint96 _feePercentage) ERC721("Meta Play Cafe", "MPC") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, _client); 
        _grantRole(OPERATOR_ROLE, msg.sender); 
        setBaseURI(baseURI);  
        _setDefaultRoyalty(_client, _feePercentage);
    }

    modifier onlyIfNotSoldOut(uint256 _count) {
        require(
            totalSupply() + _count <= MAX_NFT,
            "Transaction will exceed maximum supply of NFTs"
        );
        _;
    }

    /*External Function*/

    function setSaleStatus(SALE_STATUS _status) external onlyRole (OPERATOR_ROLE) {
        saleStatus = _status;
    }

    // Alterar para iniciar a venda 
    function startAuction() external onlyRole (OPERATOR_ROLE)  {
        require(
            saleStatus == SALE_STATUS.AUCTION,
            "Sale status is not set to auction"
        );
        auctionStartAt = block.timestamp;
    }

    function burn(uint256 id) external {
        require(_exists(id) == true, "Token id do not exists" );
        _burn(id);
    }
    /*Mint Function */
    
    function auctionMint(uint256 _count)
        external
        payable
        nonReentrant
        onlyIfNotSoldOut(_count)
    {
        require(
            saleStatus == SALE_STATUS.AUCTION,
            "Auction mint is not started"
        );
        require(
            _count <= 1,
            "Minimum 0 & Maximum 1 Token can be minted per transaction"
        );
        require(
            lastMintBlock[msg.sender] != block.number,
            "Can only mint 1 Token per block"
        );

        uint256 amountRequired = priceAuction() * _count;
        require(
            msg.value >= amountRequired,
            "Incorrect ether sent with this transaction"
        );

        //devolver eth em caso de excesso, será que é valido apenas em caso de dutchAuction?
        uint256 excess = msg.value - amountRequired;

        //MintCount at the moment of the transaction
        mintCount += _count;
        lastMintBlock[msg.sender] = block.number;
        _mint(mintCount);
        
        //refunding excess eth to minter
        if (excess > 0) {
            sendValue(msg.sender, excess);
        }
    }
  
    /*Public Function*/

    /*MetaData Function */

    function setBaseURI(string memory baseURI) public onlyRole (OPERATOR_ROLE) {
        baseTokenURI = baseURI;
    }


    function reveal() public onlyRole(OPERATOR_ROLE) {
        revealed = true;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */

     function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory){
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if(revealed == false) {
            return notRevealedUri;
        }

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }


    //set the not revealed URI on IPFS
    function setNotRevealedURI(string memory _notRevealedURI) public onlyRole(OPERATOR_ROLE) {
        notRevealedUri = _notRevealedURI;
    }

    function totalSupply() public view returns (uint256) {
        return mintCount;
    }

/* Retorna o preço das NFts conforme a venda, presale or saleAuction
para presale tem que garantir as duas condiçoes, ter PRESALE_NFT e o auctionStart == 0*/

    function priceAuction() public view returns (uint256 price) {
        if (auctionStartAt == 0 && totalSupply() < PRESALE_NFT ) {
            return PRESALE_PRICE;
        } else {
            return STARTING_PRICE;
        }
    }

    /*Internal Function*/

/*need to override since this function apprear in the both contracts ERC721 and ERC7721Royalty
* since the function is internal is only visible within the contract */

    function _burn(uint256 tokenId) internal virtual override (ERC721, ERC721Royalty) onlyRole (OPERATOR_ROLE) {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    /*Private Function*/
    function _mint(uint256 tokenId) private {
        _safeMint(msg.sender, tokenId);
        emit Minted(msg.sender, tokenId);
    }

    function sendValue(address recipient, uint256 amount) private onlyRole (OPERATOR_ROLE) {
        require(address(this).balance >= amount, "Insufficient Eth balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Unable to send value, recipient may have reverted");
    }

    // EIP2981 standard Interface return. Adds to ERC721 and ERC165 Interface returns.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Royalty, AccessControl)
        returns (bool)
    {
        //IERC165
        return (interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId));
    }
}