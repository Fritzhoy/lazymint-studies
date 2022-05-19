# Estudo do contrato CBWC como base para LazyMint aplicações

Arquivo de base para entendimento e aplicação do contrato Openzeppelin padrão ERC721 aplicado a coleção de NFT CryptoBearWatchClub, código aberto disponível no <a href=" https://etherscan.io/address/0x22c594c42fcd0b9dfde27aa8976a510c9d044356#code"> Etherscan. </a> 

<div></div>

# Estudo contrato LazyMintStudy.sol 

Descrição detalhada sobre as funções do contrato em estudo.

## Contratos Importados - Import statements

O contrato LazyMintStudy herda as funções dos contratos:

### Padrão ERC721

O <a href= "https://docs.openzeppelin.com/contracts/4.x/erc721"> padrão erc721 </a> é utilizado em aplicações de tokens únicos onde um token pode ter mais valor que os outros conforme sua raridade
e utilização, esse padrão garante o "direito" de posse dos tokens não fungíveis, onde cada token gerado é único e sua raridade ou aplicabilidade está relacionada a seus atributos definidos da MetaData definida pelos variáveis: `[uri, TokenId]`, garantindo a unicidade do `TokenId`.

O `tokenId` deve ser um documento JSON em um formato.
<pre><code>
 {
    "name": "Thor's hammer",
    "description": "Mjölnir, the legendary hammer of the Norse god of thunder.",
    "image": "https://game.example/item-id-8u5h2m.png",
    "strength": 20
  }
</code></pre>

A criação do token ocorre no momento em que o usuário chama a função de `_mint`, o token será criado e enviado diretamente para a carteira do usuário que chamou a função, garantido o direito de posse ao usuário, sendo possível sua troca em mercado secundários ou a manutenção do token na carteira do usuário.  

<hr>
<div></div>

### Ownable 

Contrato básico de permissão, onde existe uma conta que é owner e a quem é conferido acesso exclusivo a algumas funções, para saber quais funções são de uso restrito do owner, checar modificador ao final da função, `  OnlyOwner `. A transferência de posse do contrato ocorre ao chamar a função `transferOwnership`. 

Para aplicação ao nosso projeto, recomendo trocarmos para o modelo de acesso `AcessControl` que permite diferentes níveis de permissão, criado através dos "roles". Como estamos lançando um projeto que o cliente deve ter acesso exclusivo a funções e nós como suporte também precisamos ter acesso, o modelo do contrato `AcessControl` supri esse tipo de demanda. 

- Default_Adim_Role: Carteira goBlockchain
- Client_Role: Carteira Cliente

### ReentrancyGuard

Contrato modulo importado da biblioteca openzeppelin, sua função principal é evitar chamadas de reentradas à função. Ao herdas suas funções teremos acesso ao modificador `nonReentrant` que pode ser adicionada as funções para assegurar a não reentrada.

Note: como existe apenas um `nonReentrant` guard, funções marcadas como `nonReentrant` não conseguem chamar uma a outra. Isso pode ser resolvido marcando uma das funções como `private` e a outra como `external nonReentrant`.  

## Declaração de Tipo - Type Declarations 

Declaração dos tipos deve ser feito próximo do seu uso em eventos ou em variáveis de estado. 

No contrato de estudo ele inicia declarando o status de venda,
utilizando um `enum SALE_STATUS `, onde cada momento de venda está nomeado. Declarado como público, recebe um `get` função de visualização.


>> Note: Pensando no nosso projeto, podemos utilizar para separar dois momentos, `Pre-Venda` e `Venda`; 

Para deixar mais automatizado, criando um contador para quantidades de NFTs que devem ser vendidas ao preço do `Pre-Venda` e que ao finalizar o quantidade de `Pre-Venda` iniciar o `Venda` com o valor final.



## Variáveis de Estado - State variables

 Variáveis de estado são armazenadas de uma forma que multiplas variáveis podem ser armazenadas no mesmo storage Slot.

`Data` é armazenada continuamente item atrás de item, começando com a primeira variável de estado armazenada no slot 0. 

Para cada variável um tamanho em bytes é determinado conforme seu tipo, items que necessitam menos de 32 bytes são compactados em um único slot, quando possível. Regras para armazenamento:

- O primeiro item em um storage `slot` é armazenado no mais baixo nível na ordem de alinhamento (Pilha).

- Valores `Value Types` utilizam apenas a quantidade de bytes necessário para seu armazenamento.

- Se um `Value Types` não cabe no espaço remanecente do slot, será armazenado no próximo storage Slot.

- `Struct` e `Array` data são sempre armazenados em um novo slot, e seus items são armazenados de forma compacta conforme essas regras.

- Items que seguem estruturas de `Array` e `Struct` sempre iniciam um novo storage Slot. 

> Por que entender sobre o mecanismo de armazenamento dos dados ? 
Como as transações na blockchain requerem `gas` para serem executadas, entender sobre a forma de armazenamento dos dados `Storage Slot` que criamos no contrato nos ajudará a aprimorar os gastos de gás e tornar nossos contratos mais eficientes.

O uso de elemento menores de 32bytes pode gerar um uso de gás elevado, já que o EVM opera em um modelo de 32bytes por vez. 

Por exemplo, para maior eficiência ordenar `variáveis` e `Struct` members em uma maneira que eles possam ser comprimidos juntos. Exemplo: declarar 'storage variables' na ordem de `uint128, uint128 e uint256` ao invés de `uint128, uint256 e uint128`. O Primeiro usará penas 2 slots enquanto o terceiro usará 3 slots.

<hr>

No contrato ele utiliza `uint246` para declarar uma quantidade finita, para nosso contrato checar real necessidade e utilizar sempre quantidades de bytes condizentes com sua aplicabilidade.

Variáveis:

`uint mintCount`
`uint Max_Supply_PreSale`
`uint Max_Supply`
`uint PRESALE_VALUE`
`uint VALUE`
`uint auctionStartAt` [??] - checar se é melhor colocar inicio no contrato ou criar uma função onde passamos o status.

Mapeamento dos endereços que mintaram na prevenda e na venda (endereço carteiro -> idToken), declarados como publico ao seja visibilidade através do `get`.

`mapping(address => uint256) public preSaleMintCount;`

`mapping(address => uint256) public SaleMintCount;`

No contrato  foi mapeado e gravar qual o último block que o endereço entrou no mint,
isso previne que contratos/pessoas mintem mais nfts do que o permitido 
no nosso caso garante que mesmo se o usuário apertar mais de uma vez o botão de mint, não irá ultrapassar 
o mint máximo permitido

   `mapping(address => uint256) public lastMintBlock;`

## Eventos - Events

Contrato em estudo apresenta o evento de `Mint`, acredito que podemos acresentar evento para início das vendas e para mudança de estados das vendas (PRESALE e SALE)

## Construtor - Constructor

No constructo temos o <it>trigger<it> para a construção do contrato ERC721 com o Nome o Símbolo do contrato dos nossos clientes.
Como também a declaração da `BaseURI` com os MetaDados das Imagens do cliente.

## Modifier

`onlyIfNotSoldOut` modificador para garantir que a função só ocorra quando tiver tokens disponíveis.

Checar se necessitamos de modificador para ação de tokens holder only?

## Funções - Functions

Funções devem estar na ordem em que aparecem nesse documento.

### External

>> setSaleStatus 

Função para setar em qual status de vendas estamos (usar no caso de não usarmos o contador para automatizar isso.)

>> WithdrawAll 

No nosso caso vamos utilizar o contrato do splitPayment do openzepellin, então não usaremos essa função.

>> setMerkleRoot 

Ainda não li sobre essa função, checar na sequência 

>> StartAuction

inicia a venda pelo DutchAuction, acredito que não vamos seguir com esse modelo.

>> reserveBears 

Utilizada caso seja necessário reservar NFTs para algum público, tipo devs, patrocinadores ou outros.

>> privateSaleWhiteList 

Usar no caso de termos uma lista para venda privada.

>> privateSaleMint

utilizar no contrato apenas no caso de termos uma venda privada. Todas funções de Mint devem ser `payable`

>> preSaleMint

Função de mintar as NFTs de fato, nosso contrato terá uma única função de Mint?
Checar se traria maior eficiência ter função de mint separadas para PRE_SALE e SALE 

Representa o numero de Nfts que esta permitido ao Caller ser mintadas na preVenda.

`_count` indica o numero de NFTs que o Caller quer mintar, função payable.

O mint de fato acontece na última linha da função, as primeiras linhas estão checando se as condições para realizar o `mint` são atendidas.

>> auctionMint

Mint por Auction, payable e nonReentrant(evitar reentrada antes de terminar todos steps da função).

- checa status de venda
- checa se a quantidade solicitada pelo user é menor ou igual ao máximo permitido
- checa se o endereço da carteira teve o mint no último block e compara com o bloco atual, se eles forem igual a transação não ocorre. Mecanismo impede bots e evita duplo Mints por engano do usuário (apertar botão duas vezes).
-Checa se o valor necessário para o mint conforme os definido no `dutchAuction`

`uint excess` - variável que armazena excessos, no caso do valor enviado na transação for maior que o requerido no momento.

`uint supply` recebe o valor de tokens mintados até o momento

`lasMintBlock` faz o mapeamento do endereço do usuário e o block que ocorreu o mint.

`for .... _mint(supply++)`

função para mintar a quantidade de tokens solicitada pelo usuário, a cada loop do for um token é mintado, `suppy++` indica qual o token a ser mintado na operação.

`if (excess>0)`

Ao final do processo, se houver excesso no valor pago pela transação e o valor gasto de fato, o usuário recebe o valor do excesso de volta.
### Public

>> setBaseUri

Função para set o `baseURI`

>> dutchAuction

Retorna o preço das NFts conforme o tempo, DutchAuction. Acho que esse modelo nao cabe para nós, DutchAuction inicia com um valor maior e com o passar do tempo vai reduzindo até checar em um valor base, definido no contrato.

#### View

>> totalSupply

Retorna o total de NFTs mintadas em circulação, podemos utilizar também o contrato da Openzepellin `ERCSupply` 





### Internal

#### View

>> _baseURI

Retorna o baseUri, nessa função está entrando variável uma string, então o retorno será o endereço do baseUri.
Checar para fazer o retorno com o Id do token, portanto a variável de entrada deve ser o TokenId,


### Private

>> _mint