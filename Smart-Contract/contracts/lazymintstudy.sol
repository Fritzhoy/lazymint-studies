pragma solidity 0.8.3

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


//contrato herdando os contratos ERC721, Ownable e ReentrancyGuard do openzeppelin
contract LazyMintStudy is ERC721, Ownable, ReentrancyGuard {
    //
    using MerkleProof for bytes32[];

//usando para mais de um tipo de lancamento de vendas 
    enum SALE_STATUS {
        OFF,
        PRIVATE_SALE,
        PRESALE,
        AUCTION
    }
//jogando o sale_status em uma váriavel pública
    SALE_STATUS public saleStatus;

//tokenURI base, provavel que sem o id ?
    string baseTokenURI;

//usou um contador para NFT mintadas, privado (usado dentro do contrato)
    uint256 private mintCount;

//quantidade de NFTs que seram liberadas na prevenda
    uint256 public constant MAX_CBWC = 10000;
    uint256 public constant PRESALE_PRICE = 500000000000000000; // 0.5 Ether

// Dutch auction related
/*Esse modelo de mint inicia em 2eth e conforme o tempo sai passando ela cai em 0,1eth
ao invés de já ter um preço fixo para o public sale, acredito nao ser algo valido pro nossos casos*/

    uint256 public auctionStartAt; // Auction timer for public mint
    uint256 public constant PRICE_DEDUCTION_PERCENTAGE = 100000000000000000; // 0.1 Ether
    uint256 public constant STARTING_PRICE = 2000000000000000000; // 2 Ether

//Entender a utilidade do merkleRoot
    bytes32 public merkleRoot;

//Mapear endereço com o token mintado na prevenda
    mapping(address => uint256) public preSaleMintCount;

//Mapear e guardar quantas NFTs podem ser mintadas na prevenda por endereço
    mapping(address => uint256) public privateSaleMintCount;

/* mapear e gravar qual o último block que o endereço entrou no mint
isso previne que contratos/pessoas mintem mais nfts do que o permitido 
no nosso caso garante que mesmo se o usuario apertar mais de uma vez o botao de mint, nao ira ultrapassar 
o mint maximo permitido*/

    mapping(address => uint256) public lastMintBlock;

//evento retornando total mintado
    event Minted(uint256 totalMinted);

/*contrutor entrando com a string basica fica publica, será definida no deploy do contrato principal
usando o contrato starndard ERC721, definindo no construct o nome e o simbolo do contrato ERC721 e 
declarando a baseURI (chamada de funçao setBaseURI), tudo acontece no deploy do contrato*/

    constructor(string memory baseURI)
        ERC721("Crypto Bear Watch Club", "CBWC")
    {
        setBaseURI(baseURI);
    }
/*modificador para garantir que a quantidade de nfts mintadas nao ultrapasse o supply maximo.
exemplo de alguem tentar mintar 10 NFTs mas tem apenas 9NFTs restante, modifier vai retornar erro*/
    modifier onlyIfNotSoldOut(uint256 _count) {
        require(
            totalSupply() + _count <= MAX_CBWC,
            "Transaction will exceed maximum supply of CBWC"
        );
        _;
    }

    // Admin only functions

/*To update sale status, definidos inicio do contrato, 
Pre_Sale e Sale, apenas para Owner... Checar se podemos deixar isso mais automático
tipo quantidade de NFT para Pre_sale e Sale */
    function setSaleStatus(SALE_STATUS _status) external onlyOwner {
        saleStatus = _status;
    }
/*Modelo de split nao muito bom, utilizar nosso modelo biblioteca
Openzeppelin */
    function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");
        sendValue(
            0x1cE20812b08c2fcD5d595cf0667072B989666E98,
            (balance * 34) / 100
        );
        sendValue(
            0x9A69c32148FA4D0a1b0C3566e0bF35FE51430C4d,
            (balance * 33) / 100
        );
        sendValue(
            0xc6D37EfCCb2e07D94037704BB1508d816915E286,
            (balance * 33) / 100
        );
    }
//Ler sobre
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

// Funcoes de mudança conforme categoria de mint, tentar deixar automatico
    function startAuction() external onlyOwner {
        require(
            saleStatus == SALE_STATUS.AUCTION,
            "Sale status is not set to auction"
        );
        auctionStartAt = block.timestamp;
    }

// Mint reservado pra patrocinio e talz
    function reserveBears(uint256 _count)
        external
        onlyOwner
        onlyIfNotSoldOut(_count)
    {
        uint256 supply = totalSupply();
        mintCount += _count;
        for (uint256 i = 0; i < _count; i++) {
            _mint(++supply);
        }
    }
/*funcao para definiir URI utilizada na construçao da Nfts, nessse formato dá para ter diversar URI
  no mesmo contrato, uri sendo uma variável do _mint*/

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

// To whitelist mint do preSale
    function privateSaleWhiteList(
        address[] calldata _whitelistAddresses,
        uint256[] calldata _allowedCount
    ) external onlyOwner {
        require(
            _whitelistAddresses.length == _allowedCount.length,
            "Input length mismatch"
        );
        for (uint256 i = 0; i < _whitelistAddresses.length; i++) {
            require(_allowedCount[i] > 0, "Invalid allowance amount");
            require(_whitelistAddresses[i] != address(0), "Zero Address");
            privateSaleMintCount[_whitelistAddresses[i]] = _allowedCount[i];
        }
    }

// funçoes de get (view)

    // Retorna o preço das NFts conforme o tempo, DutchAuction. Acho que esse modelo nao cabe para nós
    function dutchAuction() public view returns (uint256 price) {
        if (auctionStartAt == 0) {
            return STARTING_PRICE;
        } else {
            uint256 timeElapsed = block.timestamp - auctionStartAt;
            uint256 timeElapsedMultiplier = timeElapsed / 300;
            uint256 priceDeduction = PRICE_DEDUCTION_PERCENTAGE *
                timeElapsedMultiplier;

    // se o ductionAuction estiver abaixo de 0.5 ether, manter como floor price 0,5Eth
            price = 1500000000000000000 >= priceDeduction
                ? (STARTING_PRICE - priceDeduction)
                : 500000000000000000;
        }
    }

// retorna a quantidade de tokens em circulaçao do contrato
    function totalSupply() public view returns (uint256) {
        return mintCount;
    }
//retorna o baseUri, checar para fazer o retorno com o Id do token
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

//Funcoes do Mint

 //funcao de Mint do whitelist
    function privateSaleMint(uint256 _count) external onlyIfNotSoldOut(_count) {
        require(
            privateSaleMintCount[msg.sender] > 0,
            "Address not eligible for private sale mint"
        );
        require(_count > 0, "Zero mint count");
        require(
            _count <= privateSaleMintCount[msg.sender],
            "Transaction will exceed maximum NFTs allowed to mint in private sale"
        );
        require(
            saleStatus == SALE_STATUS.PRIVATE_SALE,
            "Private sale is not started"
        );

        uint256 supply = totalSupply();
        mintCount += _count;
        privateSaleMintCount[msg.sender] -= _count;
//++ pega o valor atual e soma +1 (faz o mint do proximo do supply?)
        for (uint256 i = 0; i < _count; i++) {
            _mint(++supply);
        }
    }

    /**
     * @dev '_allowedCount' representa o numero de Nfts que esta permitido ao Caller ser mintadas na preVenda,
     * '_count' indica o numero de NFTs que o Caller quer mintar, funcao payable
     */
    function presaleMint(
        bytes32[] calldata _proof,
        uint256 _allowedCount,
        uint256 _count
    ) external payable onlyIfNotSoldOut(_count) {
        require(
            merkleRoot != 0,
            "No address is eligible for presale minting yet"
        );
        require(
            saleStatus == SALE_STATUS.PRESALE,
            "Presale sale is not started"
        );
        require(
            MerkleProof.verify(
                _proof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender, _allowedCount))
            ),
            "Address not eligible for presale mint"
        );

        require(_count > 0 && _count <= _allowedCount, "Invalid mint count");
        require(
            _allowedCount >= preSaleMintCount[msg.sender] + _count,
            "Transaction will exceed maximum NFTs allowed to mint in presale"
        );
        require(
            msg.value >= PRESALE_PRICE * _count,
            "Incorrect ether sent with this transaction"
        );

        uint256 supply = totalSupply();
        mintCount += _count;
        preSaleMintCount[msg.sender] += _count;

        for (uint256 i = 0; i < _count; i++) {
            _mint(++supply);
        }
    }

    // Mint por Auction, payable e nonReentrant(evitar reentrada antes de terminar todos steps da funcao)

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
            _count > 0 && _count < 21,
            "Minimum 0 & Maximum 20 CBWC can be minted per transaction"
        );
        require(
            lastMintBlock[msg.sender] != block.number,
            "Can only mint max 20 CBWC per block"
        );

        uint256 amountRequired = dutchAuction() * _count;
        require(
            msg.value >= amountRequired,
            "Incorrect ether sent with this transaction"
        );

        //devolver eth em caso de excesso, será que é valido apenas em caso de dutchAuction?
        uint256 excess = msg.value - amountRequired;

        uint256 supply = totalSupply();
        mintCount += _count;
        lastMintBlock[msg.sender] = block.number;

        for (uint256 i = 0; i < _count; i++) {
            _mint(++supply);
        }

        //refunding excess eth to minter
        if (excess > 0) {
            sendValue(msg.sender, excess);
        }
    }
/*funcao de mint privada, checar se essa funcao está sendo chamada dentro das demais funcoes de mint,
podemos utilizar a herença do erc721?*/

    function _mint(uint256 tokenId) private {
        _safeMint(msg.sender, tokenId);
        emit Minted(tokenId);
    }

    /**
     * @dev Chamado sempre que eth estao sendo transferidos do contrato para o dono
     *
     * chamado quando o dono quer sacar os fundos, e
     * refund o excesso para os minters (checar essa funcao direito, nao entendi essa parte de retornar excesso aos minters)
     */
    function sendValue(address recipient, uint256 amount) private {
        require(address(this).balance >= amount, "Insufficient Eth balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Unable to send value, recipient may have reverted");
    }
}
