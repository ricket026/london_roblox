# Shops & trade spec: items, shopkeeping, wholesale and player-made goods

Decided 2026-10-27: shops sell **wholesale stock** bought from NPC suppliers **and player-made
goods** from jobs. A shop is a property (PROPERTY.md: Shop, Market stall, later Workshop and
Warehouse) fitted out in build mode (BUILDING.md). Shopkeeping is a way of earning on a par with a
job, not better (ECONOMY §2).

## 1. Items (the base for shops, picnics, gifts, furniture, crafting)
There is no item system yet; this is it.
- **Item definitions** in `Shared.Items`: `id`, `name`, `category`, `base` (reference price in
  pence), `stack` (max per stack), and flags: `consumable` (use emote, then gone), `holdable`
  (carried in hand: bouquet, teacup, newspaper), `furniture` (placeable, BUILDING §2), `wearable`
  (links to wardrobe), `ingredient` (crafting), `made` (only players can make it).
- **Inventory** on the account (money is account-wide, so goods are too): a **bag** (20 stacks,
  carried, can be pickpocketed: LAW §3 takes coins only, not items) and **storage** (home/shop,
  unlimited, PROPERTY §3). Gifting = hand-over prompt, both confirm (same flow as money, T11).
- Categories at launch: food & drink (tea, coffee, lemonade, buns, pies, bread, cakes, fruit),
  flowers (single stems, bouquets), clothing & hats (via the wardrobe), furniture & decor,
  stationery & papers (newspaper, letters, cards), toys (spinning top, hoop, kite), tools
  (watering can, fishing rod upgrades), chemist goods (smelling salts for revives, motor spirit).
  No alcohol, no tobacco, no weapons except via the gunsmith (LAW, certificate rules).

## 2. Shop types and fittings
The owner picks a **trade** when opening (changeable once a week): grocer, baker, confectioner,
florist, tailor/dressmaker, hatter, furniture dealer, stationer & bookseller, toy shop,
ironmonger, chemist. The trade decides which item categories it may stock, its sign style and its
NPC customer mix. A shop needs, from the kit: a **shopfront** on the street side, a **counter**
with a **till**, and **display fittings** (shelves, cases) where stock shows.
```lua
ShopSettings = { trade = "florist", sign = "Pemberton & Daughter, Florists",  -- filtered
  open = false, prices = { [itemId] = pence }, stock = { [itemId] = count },
  staff = { [userId] = { wage = pence, sell = true } }, till = 0 }
```

## 3. Getting stock
- **Wholesale suppliers** (NPC counters, open by in-game hours): Covent Garden Market (flowers,
  fruit, vegetables; early morning only, like the real market), Smithfield (meat for pies),
  Spitalfields (produce), the Docks warehouses (tea, coffee, sugar, cloth, toys, furniture
  pieces), Clerkenwell workshops (furniture, clocks, tools). **Wholesale price = 60% of base.**
  Buy in lots of 5–20 and carry (bag) or have it **delivered** to the shop (2d per lot, arrives
  after 1 in-game hour).
- **Player-made goods:** jobs that make things (baker: bread, buns, pies; tailor/dressmaker:
  outfits; carpenter (new job): furniture; florist via allotments and flower selling: bouquets;
  photographer: portrait cards) put them in the maker's bag. A maker can stock their own shop, or
  **sell to a shop** at its counter (the shopkeeper sets a buying price; both confirm). Player-made
  items carry a **"Made by ..."** tag and have no wholesale source (`made = true`), so they're what
  makes a shop special.
- Stock lives in the shop's storage and appears on its display fittings.

## 4. Selling
- **Opening:** the owner or staff with *sell* presses **Open** at the till; the sign turns to
  "Open", a map marker shows the shop and its trade. A shop is open only while someone with *sell*
  is in the server and inside the shop (or within 20 studs of the till), so shops are run, not
  vending machines, and they gather players.
- **Prices:** set per item, allowed **0.8× to 3× base** (Config), shown on the display and on the
  menu card. No bargaining with NPCs; players can haggle in RP and the shopkeeper changes a price.
- **Buying (players):** walk up to the counter → the shop menu lists stock and prices → buy. The
  money goes to the **till**; the shopkeeper banks it (or it auto-banks at close). A receipt
  appears in the buyer's ledger.
- **NPC customers:** walk in on any server (more when it's quiet: LOW_POP §1, the NPC budget) and
  buy items that fit the trade. How many and how much depends on **price** (≤ base sells fast,
  > 1.5× rarely), **location** (hubs and busy streets get more footfall), **shop appeal** (counter,
  displays, lighting and decor pieces within the shop: a small score) and the **Royal Warrant**
  (+5% NPC sales, COURT §5). Target for a well-run shop: about **£2 per real hour** of being open
  (like a labour job, ECONOMY §2), capped per hour (Config) so leaving a shop open isn't a farm.
- Purchase duty (Parliament lever, ECONOMY §6) applies to luxuries; income tax applies to a
  shop's **profit** each in-game day (sales − wholesale cost − wages), paid to the treasury.

## 5. Market stalls (the first shop)
Cheap stalls in Covent Garden Market and Spitalfields (PROPERTY §2): rent per in-game day, no
building (a fixed stall with a counter and a small display), same selling rules. On **Market Day**
(Parliament lever / EVENTS) more stalls open and NPC shoppers double.

## 6. Staff
Hire shop assistants (players) with *sell*; their wage is paid per in-game day on duty from the
owner's bank (min wage in Config). Staff sales go into the same till. Staff can't change prices
unless the owner allows it. A shop assistant is a **job** (JOBS framework, "Shop assistant": ranks
from sales made, so it's a starter job too).

## 7. New jobs this brings (JOBS §3 additions)
- **Shopkeeper** (the owner while running the shop; a station role in `Shared.Stations`,
  claim "open" while they own a shop): XP from sales, ranks give a bigger NPC footfall bonus and
  more display slots.
- **Shop assistant** (above).
- **Carpenter** (Clerkenwell workshop): makes furniture from timber (Docks) with a short crafting
  minigame per piece; sells to furniture dealers or players.
- **Delivery runner**: carries deliveries from suppliers to shops for a fee (open to any
  avatar, DESIGN §12).

## 8. Crime hooks (M5)
- **Shoplifting** (LAW §2 new row, summary, wanted 5): take an item from a display while the
  staff aren't watching (line of sight); the item goes back and the thief is fined if caught.
- **Swindling** (exists): selling something not as described, by report.
- Tills can't be robbed in v1 (the till is banked automatically at close or when it passes £5).

## 9. UI (stubs until the UI pass)
Shop menu for buyers (stock, prices, buy), till menu for staff (open/close, sales, bank the till,
restock from storage), owner settings (trade, sign, prices, staff, buying prices for player
goods), supplier counter menu (lots, delivery), item tooltip ("Made by ...").

## 10. Ledger reasons (ECONOMY §8 additions)
`shop_sale`, `shop_buy` (the customer side), `wholesale`, `delivery`, `wage_staff`, `rent`,
`property_buy`, `property_sell`, `stall_rent`, `item_trade`.
