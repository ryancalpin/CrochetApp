import Foundation

/// A bundled, real-world crochet pattern used to seed the library on demand so new users
/// (and the simulator) have something to open immediately. Written to Application Support
/// the first time it's requested, then imported like any other file.
enum SampleContent {

    static let fileName = "Sample — Classic Granny Square.md"

    /// The pattern markdown. Structured the way the AI panel + abbreviation parser expect:
    /// an H1 title, a Skill Level / Materials preamble, an Abbreviations list, and a Pattern
    /// section with numbered rounds.
    static let patternMarkdown = """
    # Classic Granny Square

    **Skill Level:** Beginner

    **Materials:** Worsted weight yarn (3–4 colors), 5.0 mm (H-8) hook, tapestry needle, scissors.

    A timeless motif worked in the round. Make one as a coaster, or stitch dozens together for
    a blanket. Change color each round for the classic look, or stay in one color for a modern,
    tonal square.

    ## Abbreviations

    - **ch** — chain
    - **sl st** — slip stitch
    - **dc** — double crochet
    - **sp** — space
    - **st** — stitch
    - **rnd** — round

    ## Gauge

    Gauge isn't critical for a single square. For a blanket, keep your tension consistent so
    every square finishes the same size.

    ## Pattern

    Begin with a slip knot, then **ch 4** and join with a **sl st** to the first chain to form a ring.

    **Round 1:** ch 3 (counts as first dc), 2 dc into the ring, ch 2, [3 dc into ring, ch 2] three
    times. Join with a sl st to the top of the beginning ch-3. *(4 groups of 3 dc, 4 ch-2 corner spaces)*

    **Round 2:** sl st into the next 2 dc and into the first ch-2 sp. ch 3, (2 dc, ch 2, 3 dc) in the
    same corner sp. ch 1, *(3 dc, ch 2, 3 dc) in next corner sp, ch 1* — repeat around. Join with a
    sl st to the top of the beginning ch-3.

    **Round 3:** sl st into the next 2 dc and into the first corner sp. ch 3, (2 dc, ch 2, 3 dc) in the
    same corner sp. ch 1, 3 dc in next ch-1 sp, ch 1, *(3 dc, ch 2, 3 dc) in next corner sp, ch 1, 3 dc
    in next ch-1 sp, ch 1* — repeat around. Join with a sl st.

    **Round 4:** Repeat Round 3, working an extra "3 dc, ch 1" group along each side as the square grows.
    Continue adding rounds until your square is the size you want.

    ## Finishing

    Fasten off, leaving a 6-inch tail. Weave in all ends with the tapestry needle. Gently block the
    square to even out the stitches and sharpen the corners.

    ## Tips

    - To join squares, hold two together and sl st or whip stitch through the back loops.
    - For a scrap blanket, keep the final round the same color on every square so they read as a set.
    """
}
