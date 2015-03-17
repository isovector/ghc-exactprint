{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-} -- for GHC.DataId
{-# LANGUAGE RankNTypes #-} -- for GHC.DataId
{-# LANGUAGE GADTs #-} -- for GHC.DataId
{-# LANGUAGE KindSignatures #-} -- for GHC.DataId
module Language.Haskell.GHC.ExactPrint.Common where

import Control.Monad.State
import Control.Monad.Writer
import Control.Monad.RWS
import Control.Monad.Identity
import Control.Applicative
import Control.Exception
import Data.Data
import Data.Maybe
import Data.List

import Language.Haskell.GHC.ExactPrint.Types
import Language.Haskell.GHC.ExactPrint.Lookup
import Language.Haskell.GHC.ExactPrint.Utils (srcSpanStartColumn, srcSpanStartLine, debug, showGhc, isListComp, ss2posEnd, deltaFromSrcSpans, rdrName2String, ss2span, ghcCommentText, isPointSrcSpan, span2ss, ss2deltaP, ghead, undelta)

import qualified Bag            as GHC
import qualified BasicTypes     as GHC
import qualified BooleanFormula as GHC
import qualified Class          as GHC
import qualified CoAxiom        as GHC
import qualified FastString     as GHC
import qualified ForeignCall    as GHC
import qualified GHC            as GHC
import qualified Outputable     as GHC
import qualified SrcLoc         as GHC


import qualified Data.Map as Map

import Control.Monad.Free.TH
import Control.Monad.Trans.Free

-- ---------------------------------------------------------------------



data LayoutFlag = LayoutRules | NoLayoutRules deriving (Show, Eq)

data AnnotationF w next where
--  AddAnnotationWorker :: KeywordId -> GHC.SrcSpan -> next -> AnnotationF w next
  Output :: w -> next -> AnnotationF w next
  OutputKD :: (DeltaPos, (GHC.SrcSpan, KeywordId)) -> next -> AnnotationF w next
  AddEofAnnotation  :: next -> AnnotationF w next
  AddDeltaAnnotation :: GHC.AnnKeywordId -> next -> AnnotationF w next
  AddDeltaAnnotationsOutside :: GHC.AnnKeywordId -> KeywordId -> next -> AnnotationF w next
  AddDeltaAnnotationsInside :: GHC.AnnKeywordId -> next -> AnnotationF w next
  AddDeltaAnnotations :: GHC.AnnKeywordId -> next -> AnnotationF w next
  AddDeltaAnnotationLs :: GHC.AnnKeywordId -> Int -> next -> AnnotationF w next
  AddDeltaAnnotationAfter :: GHC.AnnKeywordId -> next -> AnnotationF w next
  AddDeltaAnnotationExt :: GHC.SrcSpan -> GHC.AnnKeywordId -> next ->  AnnotationF w next {-
  Before :: Data a => GHC.Located a -> (GHC.SrcSpan -> DeltaPos -> GHC.SrcSpan -> DeltaPos -> next) -> AnnotationF w next
  Middle :: Data a => GHC.Located a -> DeltaPos -> Wrapped b -> ((b, APWriter) -> next) -> AnnotationF w next
  After  :: b -> LayoutFlag -> LayoutFlag -> GHC.SrcSpan -> [(KeywordId, DeltaPos)]
          -> (b -> next) -> AnnotationF w next -}
  WithAST  :: Data a => GHC.Located a -> LayoutFlag -> Wrapped b -> (b -> next) -> AnnotationF w next
  CountAnnsAP ::  GHC.AnnKeywordId -> (Int -> next) -> AnnotationF w next
  SetLayoutFlag ::  next -> AnnotationF w next
  PrintAnnString :: GHC.AnnKeywordId -> String -> next -> AnnotationF w next
  PrintAnnStringExt :: GHC.SrcSpan -> GHC.AnnKeywordId -> String -> next -> AnnotationF w next
  PrintAnnStringLs :: GHC.AnnKeywordId -> String -> Int -> next -> AnnotationF w next

--  Middle :: Data a => GHC.Located a -> DeltaPos -> Wrapped b
--          -> ((b, APWriter) -> next) -> AnnotationF w next

deriving instance Functor (AnnotationF w)

--makeFree ''AnnotationF
-- Generate by TH
output ::
  forall m_a19g1 w_a1908. MonadFree (AnnotationF w_a1908) m_a19g1 =>
  w_a1908 -> m_a19g1 ()
output p_a19g3 = liftF (Output p_a19g3 ())
addEofAnnotation ::
  forall m_a19g4 w_a1908. MonadFree (AnnotationF w_a1908) m_a19g4 =>
  m_a19g4 ()
addEofAnnotation = liftF (AddEofAnnotation ())
addDeltaAnnotation ::
  forall m_a19g6 w_a1908. MonadFree (AnnotationF w_a1908) m_a19g6 =>
  GHC.AnnKeywordId -> m_a19g6 ()
addDeltaAnnotation p_a19g8 = liftF (AddDeltaAnnotation p_a19g8 ())
addDeltaAnnotationsOutside ::
  forall m_a19g9 w_a1908. MonadFree (AnnotationF w_a1908) m_a19g9 =>
  GHC.AnnKeywordId -> KeywordId -> m_a19g9 ()
addDeltaAnnotationsOutside p_a19gb p_a19gc
  = liftF (AddDeltaAnnotationsOutside p_a19gb p_a19gc ())
addDeltaAnnotationsInside ::
  forall m_a19gd w_a1908. MonadFree (AnnotationF w_a1908) m_a19gd =>
  GHC.AnnKeywordId -> m_a19gd ()
addDeltaAnnotationsInside p_a19gf
  = liftF (AddDeltaAnnotationsInside p_a19gf ())
addDeltaAnnotations ::
  forall m_a19gg w_a1908. MonadFree (AnnotationF w_a1908) m_a19gg =>
  GHC.AnnKeywordId -> m_a19gg ()
addDeltaAnnotations p_a19gi
  = liftF (AddDeltaAnnotations p_a19gi ())
addDeltaAnnotationLs ::
  forall m_a19gj w_a1908. MonadFree (AnnotationF w_a1908) m_a19gj =>
  GHC.AnnKeywordId -> Int -> m_a19gj ()
addDeltaAnnotationLs p_a19gl p_a19gm
  = liftF (AddDeltaAnnotationLs p_a19gl p_a19gm ())
addDeltaAnnotationAfter ::
  forall m_a19gn w_a1908. MonadFree (AnnotationF w_a1908) m_a19gn =>
  GHC.AnnKeywordId -> m_a19gn ()
addDeltaAnnotationAfter p_a19gp
  = liftF (AddDeltaAnnotationAfter p_a19gp ())
addDeltaAnnotationExt ::
  forall
         m_a19gq
         w_a1908. MonadFree (AnnotationF w_a1908) m_a19gq =>
  GHC.SrcSpan -> GHC.AnnKeywordId ->  m_a19gq ()
addDeltaAnnotationExt p_a19gs p_a19gt
  = liftF (AddDeltaAnnotationExt p_a19gs p_a19gt ())

countAnnsAP :: GHC.AnnKeywordId -> Wrapped Int
countAnnsAP kwid = liftF (CountAnnsAP kwid (\i -> i))

setLayoutFlag :: Wrapped ()
setLayoutFlag = liftF (SetLayoutFlag ())

outputKD :: (DeltaPos, (GHC.SrcSpan, KeywordId)) -> Wrapped ()
outputKD kd = liftF (OutputKD kd ())

printAnnString :: GHC.AnnKeywordId -> String -> Wrapped ()
printAnnString kwid s = liftF (PrintAnnString kwid s ())

printAnnStringExt :: GHC.SrcSpan -> GHC.AnnKeywordId -> String -> Wrapped ()
printAnnStringExt ss kwid s = liftF (PrintAnnStringExt ss kwid s ())

printAnnStringLs :: GHC.AnnKeywordId -> String -> Int -> Wrapped ()
printAnnStringLs  kwid s n = liftF (PrintAnnStringLs kwid s n ())

class Data ast => AnnotateGen ast where
  annotateG :: GHC.SrcSpan -> ast -> Wrapped ()

type AnnotateT w m = FreeT (AnnotationF w)  m

-- ---------------------------------------------------------------------


data APState = APState
             { priorEndPosition :: GHC.SrcSpan
               -- | Ordered list of comments still to be allocated
             , apComments :: [Comment]
               -- | The original GHC API Annotations
             , apAnns :: GHC.ApiAnns
             }

data EPState = EPState
             { epPos       :: Pos -- ^ Current output position
             , epAnns      :: Anns
             , epAnnKds    :: [[(KeywordId, DeltaPos)]] -- MP: Could this be moved to the local state with suitable refactoring?
             }

data StackItem = StackItem
               { -- | Current `SrcSpan`
                 curSrcSpan :: GHC.SrcSpan
                 -- |  `SrcSpan` of the immediately prior scope
               , prevSrcSpan :: GHC.SrcSpan
                 -- | The offset required to get from the prior end point to the
                 -- | The offset required to get from the prior end point to the
                 -- start of the current SrcSpan. Accessed via `getEntryDP`
               , offset     :: DeltaPos
                 -- | Offsets for the elements annotated in this `SrcSpan`
               -- | Indicates whether the contents of this SrcSpan are
               -- subject to vertical alignment layout rules
                 -- | The constructor name of the AST element, to
                 -- distinguish between nested elements that have the same
                 -- `SrcSpan` in the AST.
               , annConName :: AnnConName
               }

data EPStack = EPStack
              { epStack     :: (ColOffset,ColDelta) -- ^ stack of offsets that currently apply
              , epSrcSpan  :: GHC.SrcSpan
              }

initialEPStack :: GHC.SrcSpan -> EPStack
initialEPStack ss = EPStack
    { epStack     = (0,0)
    , epSrcSpan   = ss
    }

initialStackItem :: StackItem
initialStackItem =
  StackItem
    { curSrcSpan = GHC.noSrcSpan
    , prevSrcSpan = GHC.noSrcSpan
    , offset = DP (0,0)
    , annConName = annGetConstr ()
    }

defaultAPState :: GHC.SrcSpan -> GHC.ApiAnns -> APState
defaultAPState priorEnd ga =
  let cs = flattenedComments ga in
    APState
      { priorEndPosition = priorEnd
      , apComments = cs
      , apAnns     = ga    -- $
      }

defaultEPState :: Anns -> EPState
defaultEPState as = EPState
      { epPos    = (1,1)
      , epAnns   = as
      , epAnnKds = []
      }

data APWriter = APWriter
  { -- Final list of annotations
    finalAnns :: Endo (Map.Map AnnKey Annotation)
    -- Used locally to pass Keywords, delta pairs relevant to a specific
    -- subtree to the parent.
  , annKds :: [(KeywordId, DeltaPos)]
    -- Used locally to report a subtrees aderhence to haskell's layout
    -- rules.
  , layoutFlag :: LayoutFlag
  }


instance Monoid LayoutFlag where
  mempty = NoLayoutRules
  LayoutRules `mappend` _ = LayoutRules
  _ `mappend` LayoutRules = LayoutRules
  _ `mappend` _           = NoLayoutRules

tellFinalAnn :: (AnnKey, Annotation) -> AP ()
tellFinalAnn (k, v) =
  tell (mempty { finalAnns = Endo (Map.insertWith (<>) k v) })

tellKd :: (KeywordId, DeltaPos) -> AP ()
tellKd kd = tell (mempty { annKds = [kd] })

setLayoutFlag' :: AP ()
setLayoutFlag' = tell (mempty {layoutFlag = LayoutRules})

instance Monoid APWriter where
  mempty = APWriter mempty mempty mempty
  (APWriter a1 b1 c1) `mappend` (APWriter a2 b2 c2)
    = APWriter (a1 <> a2) (b1 <> b2) (c1 <> c2)


-- | Type used in the AP Monad. The state variables maintain
--    - the current SrcSpan and the constructor of the thing it encloses
--      as a stack to the root of the AST as it is traversed,
--    - the srcspan of the last thing annotated, to calculate delta's from
--    - extra data needing to be stored in the monad
--    - the annotations provided by GHC
type Wrapped a = AnnotateT (AnnKey, Annotation) Identity a

type AP = RWS StackItem APWriter APState

type EP = RWS EPStack (Endo String) EPState

runAP :: Wrapped () -> GHC.ApiAnns -> GHC.SrcSpan -> Anns
runAP action ga priorEnd =
  ($ mempty) . appEndo . finalAnns . snd
  . (\action -> execRWS action initialStackItem (defaultAPState priorEnd ga))
  . simpleInterpret $ action


runEP :: Wrapped () -> GHC.SrcSpan -> Anns -> String
runEP action ss ans =
  flip appEndo "" . snd
  . (\action -> execRWS action (initialEPStack ss) (defaultEPState ans))
  . printInterpret $ action

simpleInterpret :: AnnotateT (AnnKey, Annotation) Identity a -> AP a
simpleInterpret = iterTM go
  where
    go :: AnnotationF (AnnKey, Annotation) (AP a) -> AP a
    go (Output w next) = next
    go (AddEofAnnotation next) = addEofAnnotation' >> next
    go (AddDeltaAnnotation kwid next) =
      addDeltaAnnotation' kwid >> next
    go (AddDeltaAnnotationsOutside akwid kwid next) = addDeltaAnnotationsOutside' akwid kwid >> next
    go (AddDeltaAnnotationsInside akwid next) = addDeltaAnnotationsInside' akwid >> next
    go (AddDeltaAnnotations akwid next) = addDeltaAnnotations' akwid >> next
    go (AddDeltaAnnotationLs akwid n next) = addDeltaAnnotationLs' akwid n >> next
    go (AddDeltaAnnotationAfter akwid next) = addDeltaAnnotationAfter' akwid >> next
    go (AddDeltaAnnotationExt ss akwid next) = addDeltaAnnotationExt' ss akwid >> next
    go (WithAST lss layoutflag prog next) =
      withAST' lss layoutflag (simpleInterpret prog) >>= next
    go (OutputKD (kwid, (_, dp)) next) = tellKd (dp, kwid) >> next
    go (CountAnnsAP kwid next) = countAnnsAP' kwid >>= next
    go (SetLayoutFlag next) = setLayoutFlag' >> next
    go (PrintAnnString akwid s next) = addDeltaAnnotation' akwid >> next
    go (PrintAnnStringExt ss akwid _ next) = addDeltaAnnotationExt' ss akwid >> next
    go (PrintAnnStringLs akwid _ n next) = addDeltaAnnotationLs' akwid n >> next

beforeAction :: GHC.GenLocated GHC.SrcSpan e
                 -> (GHC.SrcSpan
                     -> DeltaPos
                     -> GHC.SrcSpan
                     -> DeltaPos
                     -> AP b)
                 -> AP b
beforeAction lss act = do
  pe <- getPriorEnd
  let ss = (GHC.getLoc lss)
  let edp = deltaFromSrcSpans pe ss
  edp' <- adjustDeltaForOffsetM edp
  act pe edp' ss edp

--middleAction :: GHC.Located a -> DeltaPos -> AP b -> _ -> AP c
middleAction :: Data a => GHC.Located a -> DeltaPos -> AP b -> ((b, APWriter) -> AP c) -> AP c
middleAction lss edp wrapped k = censor maskWriter $ do
  withSrcSpanAP lss edp (listen wrapped) >>= k
  where
    maskWriter s = s { annKds = []
                     , layoutFlag = NoLayoutRules }

afterAction :: LayoutFlag -> GHC.SrcSpan -> [(KeywordId, DeltaPos)] -> AP ()
afterAction lf ss annkds = do
  (dp,nl)  <- getCurrentDP lf
  finaledp <- getEntryDP
  addAnnotationsAP (Ann finaledp nl (srcSpanStartColumn ss) dp annkds)

printInterpret :: AnnotateT (AnnKey, Annotation) Identity a -> EP a
printInterpret = iterTM go
  where
    go :: AnnotationF (AnnKey, Annotation) (EP a) -> EP a
    go (Output w next) = next
    go (AddEofAnnotation next) = printStringAtMaybeAnn (G GHC.AnnEofPos) "" >> next
    go (AddDeltaAnnotation kwid next) =
      justOne kwid  >> next
    go (AddDeltaAnnotationsOutside akwid kwid next) =
      printStringAtMaybeAnnAll kwid ";"  >> next
    go (AddDeltaAnnotationsInside akwid next) =
      allAnns akwid >> next
    go (AddDeltaAnnotations akwid next) =
      allAnns akwid >> next
    go (AddDeltaAnnotationLs akwid _ next) =
      justOne akwid >> next
    go (AddDeltaAnnotationAfter akwid next) =
      justOne akwid >> next
    go (AddDeltaAnnotationExt ss akwid next) =
      justOne akwid >> next
    go (WithAST lss layoutflag action next) =
      exactPC lss (printInterpret action) >>= next
    go (OutputKD _ next) =
      next
    go (CountAnnsAP kwid next) =
      countAnnsEP (G kwid) >>= next
    go (SetLayoutFlag next) =
      next
    go (PrintAnnString akwid s next) = printStringAtMaybeAnn (G akwid) s >> next
    go (PrintAnnStringExt _ akwid s next) = printStringAtMaybeAnn (G akwid) s >> next
    go (PrintAnnStringLs akwid s _ next) = printStringAtMaybeAnn (G akwid) s >> next

justOne kwid = printStringAtMaybeAnn (G kwid) (keywordToString kwid)
allAnns kwid = printStringAtMaybeAnnAll (G kwid) (keywordToString kwid)


-- ---------------------------------------------------------------------

flattenedComments :: GHC.ApiAnns -> [Comment]
flattenedComments (_,cm) = map tokComment . GHC.sortLocated . concat $ Map.elems cm

-- -------------------------------------

getSrcSpanAP :: AP GHC.SrcSpan
getSrcSpanAP = asks curSrcSpan

getPriorSrcSpanAP :: AP GHC.SrcSpan
getPriorSrcSpanAP = asks prevSrcSpan

withSrcSpanAP :: Data a => (GHC.Located a) -> DeltaPos -> AP b -> AP b
withSrcSpanAP (GHC.L l a) edp =
  local (\s -> let previousSrcSpan = curSrcSpan s in
               s { curSrcSpan = l
                 , prevSrcSpan = previousSrcSpan
                 , offset = edp
                 , annConName = annGetConstr a
                 })


getEntryDP :: AP DeltaPos
getEntryDP = asks offset

getUnallocatedComments :: AP [Comment]
getUnallocatedComments = gets apComments

putUnallocatedComments :: [Comment] -> AP ()
putUnallocatedComments cs = modify (\s -> s { apComments = cs } )

-- ---------------------------------------------------------------------

adjustDeltaForOffsetM :: DeltaPos -> AP DeltaPos
adjustDeltaForOffsetM dp = do
  colOffset <- getCurrentColOffset
  return (adjustDeltaForOffset colOffset dp)

adjustDeltaForOffset :: Int -> DeltaPos -> DeltaPos
adjustDeltaForOffset _colOffset dp@(DP (0,_)) = dp -- same line
adjustDeltaForOffset  colOffset    (DP (l,c)) = DP (l,c - colOffset)

-- ---------------------------------------------------------------------

-- | Get the current column offset
getCurrentColOffset :: AP ColOffset
getCurrentColOffset = srcSpanStartColumn <$> getSrcSpanAP

-- |Get the difference between the current and the previous
-- colOffsets, if they are on the same line
getCurrentDP :: LayoutFlag -> AP (ColOffset,LineChanged)
getCurrentDP layoutOn = do
  -- Note: the current col offsets are not needed here, any
  -- indentation should be fully nested in an AST element
  ss <- getSrcSpanAP
  ps <- getPriorSrcSpanAP
  let boolLayoutFlag = case layoutOn of { LayoutRules -> True; NoLayoutRules -> False}
      colOffset = if srcSpanStartLine ss == srcSpanStartLine ps
                    then srcSpanStartColumn ss - srcSpanStartColumn ps
                    else srcSpanStartColumn ss
      r = case ( boolLayoutFlag , srcSpanStartLine ss == srcSpanStartLine ps) of
             (True,  True) -> (colOffset, LayoutLineSame)
             (True, False) -> (colOffset, LayoutLineChanged)
             (False, True) -> (colOffset, LineSame)
             (False,False) -> (colOffset, LineChanged)
  return r
    `debug` ("getCurrentDP:layoutOn=" ++ show layoutOn)

-- ---------------------------------------------------------------------

-- |Note: assumes the prior end SrcSpan stack is nonempty
getPriorEnd :: AP GHC.SrcSpan
getPriorEnd = gets priorEndPosition

setPriorEnd :: GHC.SrcSpan -> AP ()
setPriorEnd pe = modify (\s -> s { priorEndPosition = pe })

-- -------------------------------------

getAnnotationAP :: GHC.AnnKeywordId -> AP [GHC.SrcSpan]
getAnnotationAP an = do
    ga <- gets apAnns
    ss <- getSrcSpanAP
    return $ GHC.getAnnotation ga ss an

getAndRemoveAnnotationAP :: GHC.SrcSpan -> GHC.AnnKeywordId -> AP [GHC.SrcSpan]
getAndRemoveAnnotationAP sp an = do
    ga <- gets apAnns
    let (r,ga') = GHC.getAndRemoveAnnotation ga sp an
    r <$ modify (\s -> s { apAnns = ga' })


tokComment :: GHC.Located GHC.AnnotationComment -> Comment
tokComment t@(GHC.L lt _) = Comment (ss2span lt) (ghcCommentText t)

-- -------------------------------------

-- |Add some annotation to the currently active SrcSpan
addAnnotationsAP :: Annotation -> AP ()
addAnnotationsAP ann = do
    l <- ask
    tellFinalAnn ((getAnnKey l),ann)

getAnnKey :: StackItem -> AnnKey
getAnnKey StackItem {curSrcSpan, annConName} = AnnKey curSrcSpan annConName

-- -------------------------------------

addAnnDeltaPos :: (GHC.SrcSpan,KeywordId) -> DeltaPos -> AP ()
addAnnDeltaPos (_s,kw) dp = tellKd (kw, dp)

-- -------------------------------------

--withAST' :: Data a => GHC.Located a -> LayoutFlag -> Wrapped b -> Wrapped b
--withAST' l lf action  = join . liftF $ Recurse l lf action (return ())

withAST :: Data a => GHC.Located a -> LayoutFlag -> Wrapped b -> Wrapped b
withAST lss layout action = liftF (WithAST lss layout prog (\b -> b))
  where
    prog = do
      r <- action
      -- Automatically add any trailing comma or semi
      addDeltaAnnotationAfter GHC.AnnComma
      addDeltaAnnotationsOutside GHC.AnnSemi AnnSemiSep
      return r

-- | Enter a new AST element. Maintain SrcSpan stack
withAST' :: Data a => GHC.Located a -> LayoutFlag -> AP b -> AP b
withAST' lss layout action = do
  -- Calculate offset required to get to the start of the SrcSPan
  pe <- getPriorEnd
  let ss = (GHC.getLoc lss)
  let edp = deltaFromSrcSpans pe ss
  edp' <- adjustDeltaForOffsetM edp
  -- need to save edp', and put it in Annotation

  withSrcSpanAP lss edp' (do

    let maskWriter s = s { annKds = []
                         , layoutFlag = NoLayoutRules }

    (res, w) <-
      (censor maskWriter (listen action))

    (dp,nl)  <- getCurrentDP (layout <> layoutFlag w)
    finaledp <- getEntryDP
    let kds = annKds w
    addAnnotationsAP (Ann finaledp nl (srcSpanStartColumn ss) dp kds)
      `debug` ("leaveAST:(ss,edp,dp,kds)=" ++ show (showGhc ss,edp,dp,kds,dp))
    return res)

{-
withAST' :: Data a => GHC.Located a -> LayoutFlag -> Wrapped b -> Wrapped b
withAST' lss@(GHC.L l ast) layout action = do

  -- Calculate offset required to get to the start of the SrcSPan

  pe <- getPriorEnd
  let ss = (GHC.getLoc lss)
  let edp = deltaFromSrcSpans pe ss
  edp' <- adjustDeltaForOffsetM edp
  -- need to save edp', and put it in Annotation
  --(withContext kds l an . withSrcSpanAP lss edp') (do


  (res, w) <-
   middle lss edp'
     (do
        r <- action
        -- Automatically add any trailing comma or semi
        addDeltaAnnotationAfter GHC.AnnComma
        addDeltaAnnotationsOutside GHC.AnnSemi AnnSemiSep
        return r)
  after res layout (layoutFlag w) ss (annKds w)
    {-
    return res)
    -}
-}
-- |First move to the given location, then call exactP
exactPC :: Data ast => GHC.Located ast -> EP a -> EP a
exactPC a@(GHC.L l ast) action =
    do return () `debug` ("exactPC entered for:" ++ showGhc l)
       ma <- getAndRemoveAnnotation a
       let an@(Ann _edp _nl _sc _dc kds) = fromMaybe annNone ma
       withContext kds l an action

withContext :: [(KeywordId, DeltaPos)]
            -> GHC.SrcSpan
            -> Annotation
            -> EP a -> EP a
withContext kds l an = withKds kds . withSrcSpan l . withOffset an


getPos :: EP Pos
getPos = gets epPos

setPos :: Pos -> EP ()
setPos l = modify (\s -> s {epPos = l})

-- ---------------------------------------------------------------------

-- | Given an annotation associated with a specific SrcSpan, determines a new offset relative to the previous
-- offset
--
withOffset :: Annotation -> EP a -> EP a
withOffset a@(Ann (DP (edLine, edColumn)) newline originalStartCol annDelta _) k = do
  -- The colOffset is the offset to be used when going to the next line.
  -- The colIndent is how far the current code block has been indented.
  (colOffset, colIndent) <- asks epStack
  (_l, currentColumn) <- getPos
  let
      -- Add extra indentation for this SrcSpan
     colOffset' = annDelta + colOffset
     -- Work out where new column starts, based on the entry delta
     newStartColumn = if edLine == 0
                          then edColumn + currentColumn -- same line, use entry delta
                          else colOffset -- different line, use current offset
     newColIndent        = newStartColumn - originalStartCol

     offsetValNewIndent  = (colOffset' + (newColIndent - colIndent), newColIndent)
     offsetValSameIndent = (colOffset'            ,                  colIndent)
     offsetValNewline    = (annDelta   + colIndent,                  colIndent)

     newOffset =
        case newline of
          -- For use by AST modifiers, to preserve the indentation
          -- level for the next line after an AST modification
          KeepOffset  -> offsetValNewline

          -- Generated during the annotation phase
          LineChanged       -> offsetValNewline
          LayoutLineChanged -> offsetValNewline

          LineSame          -> offsetValSameIndent
          LayoutLineSame    -> offsetValNewIndent
  local (\s -> s {epStack = newOffset }) k
    `debug` ("pushOffset:(a, colOffset, colIndent, currentColumn, newOffset)="
                 ++ show (a, colOffset, colIndent, currentColumn, newOffset))

-- |Get the current column offset
getOffset :: EP ColOffset
getOffset = asks (fst . epStack)

-- ---------------------------------------------------------------------

withSrcSpan :: GHC.SrcSpan -> EP a -> EP a
withSrcSpan ss = local (\s -> s {epSrcSpan = ss})

getAndRemoveAnnotation :: (Data a) => GHC.Located a -> EP (Maybe Annotation)
getAndRemoveAnnotation a = do
  (r, an') <- gets (getAndRemoveAnnotationEP a . epAnns)
  modify (\s -> s { epAnns = an' })
  return r

withKds :: [(KeywordId, DeltaPos)] -> EP a -> EP a
withKds kd action = do
  modify (\s -> s { epAnnKds = kd : (epAnnKds s) })
  r <- action
  modify (\s -> s { epAnnKds = tail (epAnnKds s) })
  return r

-- | Get and remove the first item in the (k,v) list for which the k matches.
-- Return the value, together with any comments skipped over to get there.
destructiveGetFirst :: KeywordId -> ([(KeywordId,v)],[(KeywordId,v)])
                    -> ([(KeywordId,v)], Maybe v,[(KeywordId,v)])
destructiveGetFirst _key (acc,[]) = ([], Nothing ,acc)
destructiveGetFirst  key (acc,((k,v):kvs))
  | k == key = let (cs,others) = commentsAndOthers acc in (cs, Just v ,others++kvs)
  | otherwise = destructiveGetFirst key (acc++[(k,v)],kvs)
  where
    commentsAndOthers kvs' = partition isComment kvs'
    isComment ((AnnComment _),_) = True
    isComment _              = False

-- |destructive get, hence use an annotation once only
getAnnFinal :: KeywordId -> EP ([DComment], Maybe DeltaPos)
getAnnFinal kw = do
  kd <- gets epAnnKds
  let (r, kd', dcs) = case kd of
                  []    -> (Nothing ,[], [])
                  (k:kds) -> (r',kk:kds, dcs')
                    where (cs', r',kk) = destructiveGetFirst kw ([],k)
                          dcs' = concatMap keywordIdToDComment cs'
  modify (\s -> s { epAnnKds = kd' })
  return (dcs, r)

-- ---------------------------------------------------------------------

getStoredListSrcSpan :: EP GHC.SrcSpan
getStoredListSrcSpan = do
  kd <- gets epAnnKds
  let
    isAnnList ((AnnList _),_) = True
    isAnnList _               = False

    kdf = ghead "getStoredListSrcSpan.1" kd
    (AnnList ss,_) = ghead "getStoredListSrcSpan.2" $ filter isAnnList kdf
  return ss

-- ---------------------------------------------------------------------

keywordIdToDComment :: (KeywordId, DeltaPos) -> [DComment]
keywordIdToDComment (AnnComment comment,_dp) = [comment]
keywordIdToDComment _                   = []

-- |non-destructive get
peekAnnFinal :: KeywordId -> EP (Maybe DeltaPos)
peekAnnFinal kw = do
  (_, r, _) <- (\kd -> destructiveGetFirst kw ([], kd)) <$> gets (head . epAnnKds)
  return r
-- ---------------------------------------------------------------------
printString :: String -> EP ()
printString str = do
  (l,c) <- gets epPos
  setPos (l, c + length str)
  tell (Endo $ showString str )

newLine :: EP ()
newLine = do
    (l,_) <- getPos
    printString "\n"
    setPos (l+1,1)

padUntil :: Pos -> EP ()
padUntil (l,c) = do
    (l1,c1) <- getPos
    case  {- trace (show ((l,c), (l1,c1))) -} () of
     _ {-()-} | l1 >= l && c1 <= c -> printString $ replicate (c - c1) ' '
              | l1 < l             -> newLine >> padUntil (l,c)
              | otherwise          -> return ()

printWhitespace :: Pos -> EP ()
printWhitespace p = do
  -- mPrintComments p >> padUntil p
  padUntil p

printStringAt :: Pos -> String -> EP ()
printStringAt p str = printWhitespace p >> printString str

-- ---------------------------------------------------------------------

-- |This should be the final point where things are mode concrete,
-- before output. Hence the point where comments can be inserted
printStringAtLsDelta :: [DComment] -> [DeltaPos] -> String -> EP ()
printStringAtLsDelta cs mc s =
  case reverse mc of
    (cl:_) -> do
      p <- getPos
      colOffset <- getOffset
      if isGoodDeltaWithOffset cl colOffset
        then do
          mapM_ printQueuedComment cs
          printStringAt (undelta p cl colOffset) s
            `debug` ("printStringAtLsDelta:(pos,s):" ++ show (undelta p cl colOffset,s))
        else return () `debug` ("printStringAtLsDelta:bad delta for (mc,s):" ++ show (mc,s))
    _ -> return ()


isGoodDeltaWithOffset :: DeltaPos -> Int -> Bool
isGoodDeltaWithOffset dp colOffset = isGoodDelta (DP (undelta (0,0) dp colOffset))

-- AZ:TODO: harvest the commonality between this and printStringAtLsDelta
printQueuedComment :: DComment -> EP ()
printQueuedComment (DComment (dp,de) s) = do
  p <- getPos
  colOffset <- getOffset
  let (dr,dc) = undelta (0,0) dp colOffset
  if isGoodDelta (DP (dr,max 0 dc)) -- do not lose comments against the left margin
    then do
      printStringAt (undelta p dp colOffset) s
         `debug` ("printQueuedComment:(pos,s):" ++ show (undelta p dp colOffset,s))
      setPos (undelta p de colOffset)
    else return () `debug` ("printQueuedComment::bad delta for (dp,s):" ++ show (dp,s))
-- ---------------------------------------------------------------------

printStringAtMaybeAnn :: KeywordId -> String -> EP ()
printStringAtMaybeAnn an str = do
  (comments, ma) <- getAnnFinal an
  printStringAtLsDelta comments (maybeToList ma) str
    `debug` ("printStringAtMaybeAnn:(an,ma,str)=" ++ show (an,ma,str))

printStringAtMaybeAnnAll :: KeywordId -> String -> EP ()
printStringAtMaybeAnnAll an str = go
  where
    go = do
      (comments, ma) <- getAnnFinal an
      case ma of
        Nothing -> return ()
        Just d  -> printStringAtLsDelta comments [d] str >> go
-- ---------------------------------------------------------------------

countAnnsEP :: KeywordId -> EP Int
countAnnsEP an = do
  ma <- peekAnnFinal an
  return (length ma)
------------------------------------------------------------------------------
-- Printing of source elements
-- | Print an AST exactly as specified by the annotations on the nodes in the tree.
-- exactPrint :: (ExactP ast) => ast -> [Comment] -> String
exactPrint :: (AnnotateGen ast) => GHC.Located ast -> String
exactPrint ast@(GHC.L l _) = runEP (annotatePC ast) l Map.empty


exactPrintAnnotated ::
     GHC.Located (GHC.HsModule GHC.RdrName) -> GHC.ApiAnns -> String
exactPrintAnnotated ast@(GHC.L l _) ghcAnns = runEP (annotatePC ast) l an
  where
    an = annotateLHsModule ast ghcAnns

exactPrintAnnotation :: AnnotateGen ast =>
  GHC.Located ast -> Anns -> String
exactPrintAnnotation ast@(GHC.L l _) an = runEP (annotatePC ast) l an
  -- `debug` ("exactPrintAnnotation:an=" ++ (concatMap (\(l,a) -> show (ss2span l,a)) $ Map.toList an ))
  --

annotateAST :: GHC.Located (GHC.HsModule GHC.RdrName) -> GHC.ApiAnns -> Anns
annotateAST ast ghcAnns = annotateLHsModule ast ghcAnns

{-
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------

printMerged :: (AnnotateGen a, AnnotateGen b) => [GHC.Located a] -> [GHC.Located b] -> Wrapped  ()
printMerged [] [] = return ()
printMerged [] bs = mapM_ annotatePC bs
printMerged as [] = mapM_ annotatePC as
printMerged (a@(GHC.L l1 _):as) (b@(GHC.L l2 _):bs) =
  if l1 < l2
    then annotatePC a >> printMerged    as (b:bs)
    else annotatePC b >> printMerged (a:as)   bs

-}
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------


-- |First move to the given location, then call exactP
annotatePC :: (AnnotateGen ast) => GHC.Located ast -> Wrapped ()
annotatePC a = withLocated a NoLayoutRules annotateG

withLocated :: Data a => GHC.Located a -> LayoutFlag -> (GHC.SrcSpan -> a -> Wrapped ()) -> Wrapped ()
withLocated a@(GHC.L l ast) layoutFlag action = do
  withAST a layoutFlag (action l ast)

annotateMaybe :: (AnnotateGen ast) => Maybe (GHC.Located ast) -> Wrapped ()
annotateMaybe Nothing    = return ()
annotateMaybe (Just ast) = annotatePC ast

annotateList :: (AnnotateGen ast) => [GHC.Located ast] -> Wrapped ()
annotateList xs = mapM_ annotatePC xs

-- | Flag the item to be annotated as requiring layout.
annotateWithLayout :: AnnotateGen ast => GHC.Located ast -> Wrapped ()
annotateWithLayout a = do
  withLocated a LayoutRules (\l ast -> annotateG l ast)

annotateListWithLayout :: AnnotateGen [GHC.Located ast] => GHC.SrcSpan -> [GHC.Located ast] -> Wrapped ()
annotateListWithLayout l ls = do
  let ss = getListSrcSpan ls
  outputKD $ ((DP (0,0)), (l,AnnList ss))
  annotateWithLayout (GHC.L ss ls)

-- ---------------------------------------------------------------------

isGoodDelta :: DeltaPos -> Bool
isGoodDelta (DP (ro,co)) = ro >= 0 && co >= 0

-- ---------------------------------------------------------------------

-- |Split the ordered list of comments into ones that occur prior to
-- the given SrcSpan and the rest
allocatePriorComments :: [Comment] -> GHC.SrcSpan -> ([Comment],[Comment])
allocatePriorComments cs ss = partition isPrior cs
  where
    (start,_) = ss2span ss
    isPrior (Comment s _)  = (fst s) < start
      `debug` ("allocatePriorComments:(s,ss,cond)=" ++ showGhc (s,ss,(fst s) < start))

-- ---------------------------------------------------------------------

addAnnotationWorker :: KeywordId -> GHC.SrcSpan -> AP ()
addAnnotationWorker ann pa = do
  if not (isPointSrcSpan pa)
    then do
      pe <- getPriorEnd
      ss <- getSrcSpanAP
      let p = deltaFromSrcSpans pe pa
      case (ann,isGoodDelta p) of
        (G GHC.AnnComma,False) -> return ()
        (G GHC.AnnSemi, False) -> return ()
        (G GHC.AnnOpen, False) -> return ()
        (G GHC.AnnClose,False) -> return ()
        _ -> do
          cs <- getUnallocatedComments
          let (allocated,cs') = allocatePriorComments cs pa
          putUnallocatedComments cs'
          return () `debug`("addAnnotationWorker:(ss,pa,allocated,cs)=" ++ showGhc (ss,pa,allocated,cs))
          mapM_ addDeltaComment allocated
          p' <- adjustDeltaForOffsetM p
          addAnnDeltaPos (ss,ann) p'
          setPriorEnd pa
              -- `debug` ("addDeltaAnnotationWorker:(ss,pe,pa,p,ann)=" ++ show (ss2span ss,ss2span pe,ss2span pa,p,ann))
    else do
      return ()
          -- `debug` ("addDeltaAnnotationWorker::point span:(ss,ma,ann)=" ++ show (ss2span pa,ann))

-- ---------------------------------------------------------------------

addDeltaComment :: Comment -> AP ()
addDeltaComment (Comment paspan str) = do
  let pa = span2ss paspan
  pe <- getPriorEnd
  ss <- getSrcSpanAP
  let p = deltaFromSrcSpans pe pa
  p' <- adjustDeltaForOffsetM p
  setPriorEnd pa
  let e = ss2deltaP (ss2posEnd pe) (snd paspan)
  e' <- adjustDeltaForOffsetM e
  addAnnDeltaPos (ss,AnnComment (DComment (p',e') str)) p'

-- ---------------------------------------------------------------------

-- | Look up and add a Delta annotation at the current position, and
-- advance the position to the end of the annotation
addDeltaAnnotation' :: GHC.AnnKeywordId -> AP ()
addDeltaAnnotation' ann = do
  ss <- getSrcSpanAP
  ma <- getAnnotationAP ann
  case nub ma of -- ++AZ++ TODO: get rid of duplicates earlier
    [] -> return () `debug` ("addDeltaAnnotation empty ma for:" ++ show ann)
    [pa] -> addAnnotationWorker (G ann) pa
    _ -> error $ "addDeltaAnnotation:(ss,ann,ma)=" ++ showGhc (ss,ann,ma)

-- | Look up and add a Delta annotation appearing beyond the current
-- SrcSpan at the current position, and advance the position to the
-- end of the annotation
addDeltaAnnotationAfter' :: GHC.AnnKeywordId -> AP ()
addDeltaAnnotationAfter' ann = do
  ss <- getSrcSpanAP
  ma <- getAnnotationAP ann
  let ma' = filter (\s -> not (GHC.isSubspanOf s ss)) ma
  case ma' of
    [] -> return () `debug` ("addDeltaAnnotation empty ma")
    [pa] -> addAnnotationWorker (G ann) pa
    _ -> error $ "addDeltaAnnotation:(ss,ann,ma)=" ++ showGhc (ss,ann,ma)

-- | Look up and add a Delta annotation at the current position, and
-- advance the position to the end of the annotation
addDeltaAnnotationLs' :: GHC.AnnKeywordId -> Int -> AP ()
addDeltaAnnotationLs' ann off = do
  ma <- getAnnotationAP ann
  case (drop off ma) of
    [] -> return ()
        -- `debug` ("addDeltaAnnotationLs:missed:(off,pe,ann,ma)=" ++ show (off,ss2span pe,ann,fmap ss2span ma))
    (pa:_) -> addAnnotationWorker (G ann) pa

-- | Look up and add possibly multiple Delta annotation at the current
-- position, and advance the position to the end of the annotations
addDeltaAnnotations' :: GHC.AnnKeywordId -> AP ()
addDeltaAnnotations' ann = do
  ma <- getAnnotationAP ann
  let do_one ap' = addAnnotationWorker (G ann) ap'
                    -- `debug` ("addDeltaAnnotations:do_one:(ap',ann)=" ++ showGhc (ap',ann))
  mapM_ do_one (sort ma)

-- | Look up and add possibly multiple Delta annotations enclosed by
-- the current SrcSpan at the current position, and advance the
-- position to the end of the annotations
addDeltaAnnotationsInside' :: GHC.AnnKeywordId -> AP ()
addDeltaAnnotationsInside' ann = do
  ss <- getSrcSpanAP
  ma <- getAnnotationAP ann
  let do_one ap' = addAnnotationWorker (G ann) ap'
                    -- `debug` ("addDeltaAnnotations:do_one:(ap',ann)=" ++ showGhc (ap',ann))
  mapM_ do_one (sort $ filter (\s -> GHC.isSubspanOf s ss) ma)

-- | Look up and add possibly multiple Delta annotations not enclosed by
-- the current SrcSpan at the current position, and advance the
-- position to the end of the annotations
addDeltaAnnotationsOutside' :: GHC.AnnKeywordId -> KeywordId -> AP ()
addDeltaAnnotationsOutside' gann ann = do
  ss <- getSrcSpanAP
  if ss2span ss == ((1,1),(1,1))
    then return ()
    else do
      -- ma <- getAnnotationAP ss gann
      ma <- getAndRemoveAnnotationAP ss gann
      let do_one ap' = addAnnotationWorker ann ap'
                        -- `debug` ("addDeltaAnnotations:do_one:(ap',ann)=" ++ showGhc (ap',ann))
      mapM_ do_one (sort $ filter (\s -> not (GHC.isSubspanOf s ss)) ma)

-- | Add a Delta annotation at the current position, and advance the
-- position to the end of the annotation
addDeltaAnnotationExt' :: GHC.SrcSpan -> GHC.AnnKeywordId -> AP ()
addDeltaAnnotationExt' s ann = addAnnotationWorker (G ann) s



addEofAnnotation' :: AP ()
addEofAnnotation' = do
  pe <- getPriorEnd
  ss <- getSrcSpanAP
  ma <- withSrcSpanAP (GHC.noLoc ()) (DP (0,0)) (getAnnotationAP GHC.AnnEofPos)
  case ma of
    [] -> return ()
    (pa:pss) -> do
      cs <- getUnallocatedComments
      mapM_ addDeltaComment cs
      let DP (r,c) = deltaFromSrcSpans pe pa
      addAnnDeltaPos (ss,G GHC.AnnEofPos) (DP (r, c - 1))
      setPriorEnd pa


countAnnsAP' :: GHC.AnnKeywordId -> AP Int
countAnnsAP' ann = do
  ma <- getAnnotationAP ann
  return (length ma)

-- ---------------------------------------------------------------------
-- Managing lists which have been separated, e.g. Sigs and Binds

prepareListAnnotation :: AnnotateGen a => [GHC.Located a] -> [(GHC.SrcSpan,Wrapped ())]
prepareListAnnotation ls = map (\b@(GHC.L l _) -> (l,annotatePC b)) ls

applyListAnnotations :: [(GHC.SrcSpan, Wrapped ())] -> Wrapped ()
applyListAnnotations ls
  = mapM_ snd $ sortBy (\(a,_) (b,_) -> compare a b) ls

-- ---------------------------------------------------------------------
-- Start of application specific part

-- ---------------------------------------------------------------------

annotateLHsModule :: GHC.Located (GHC.HsModule GHC.RdrName) -> GHC.ApiAnns
                  -> Anns
annotateLHsModule modu@(GHC.L ss _) ghcAnns
   = runAP (annotatePC modu) ghcAnns ss

-- ---------------------------------------------------------------------

instance AnnotateGen (GHC.HsModule GHC.RdrName) where
  annotateG lm (GHC.HsModule mmn mexp imps decs mdepr _haddock) = do


    case mmn of
      Nothing -> return ()
      Just (GHC.L ln mn) -> do
        addDeltaAnnotation GHC.AnnModule
        printAnnStringExt ln GHC.AnnVal (GHC.moduleNameString mn)


    annotateMaybe mdepr

    case mexp of
      Nothing   -> return ()
      Just expr -> annotatePC expr

    addDeltaAnnotation GHC.AnnWhere
    addDeltaAnnotation GHC.AnnOpenC -- Possible '{'
    addDeltaAnnotations GHC.AnnSemi -- possible leading semis
    mapM_ annotatePC imps

    annotateList decs

    addDeltaAnnotation GHC.AnnCloseC -- Possible '}'

    addEofAnnotation

-- ---------------------------------------------------------------------

instance AnnotateGen GHC.WarningTxt where
  annotateG _ (GHC.WarningTxt (GHC.L ls txt) lss) = do
    printAnnStringExt ls GHC.AnnOpen txt
    addDeltaAnnotation GHC.AnnOpenS
    mapM_ annotatePC lss
    addDeltaAnnotation GHC.AnnCloseS
    printAnnString GHC.AnnClose "#-}"

  annotateG _ (GHC.DeprecatedTxt (GHC.L ls txt) lss) = do
    printAnnStringExt ls GHC.AnnOpen txt
    addDeltaAnnotation GHC.AnnOpenS
    mapM_ annotatePC lss
    addDeltaAnnotation GHC.AnnCloseS
    printAnnString GHC.AnnClose "#-}"

-- ---------------------------------------------------------------------

instance (GHC.DataId name,AnnotateGen name)
  => AnnotateGen [GHC.LIE name] where
   annotateG _ ls = do
     addDeltaAnnotation GHC.AnnHiding -- in an import decl
     addDeltaAnnotation GHC.AnnOpenP -- '('
     mapM_ annotatePC ls
     addDeltaAnnotation GHC.AnnCloseP -- ')'

instance (GHC.DataId name,AnnotateGen name)
  => AnnotateGen (GHC.IE name) where
  annotateG _ ie = do

    case ie of
        (GHC.IEVar ln) -> do
          addDeltaAnnotation GHC.AnnPattern
          addDeltaAnnotation GHC.AnnType
          annotatePC ln

        (GHC.IEThingAbs ln) -> do
          addDeltaAnnotation GHC.AnnType
          annotatePC ln

        (GHC.IEThingWith ln ns) -> do
          annotatePC ln
          addDeltaAnnotation GHC.AnnOpenP
          mapM_ annotatePC ns
          addDeltaAnnotation GHC.AnnCloseP

        (GHC.IEThingAll ln) -> do
          annotatePC ln
          addDeltaAnnotation GHC.AnnOpenP
          addDeltaAnnotation GHC.AnnDotdot
          addDeltaAnnotation GHC.AnnCloseP

        (GHC.IEModuleContents (GHC.L lm mn)) -> do
          addDeltaAnnotation GHC.AnnModule
          printAnnStringExt lm GHC.AnnVal (GHC.moduleNameString mn)


-- ---------------------------------------------------------------------

instance AnnotateGen GHC.RdrName where
  annotateG l n = do
    case rdrName2String n of
      "[]" -> do
        addDeltaAnnotation GHC.AnnOpenS  -- '['
        addDeltaAnnotation GHC.AnnCloseS -- ']'
      "()" -> do
        addDeltaAnnotation GHC.AnnOpenP  -- '('
        addDeltaAnnotation GHC.AnnCloseP -- ')'
      "(##)" -> do
        printAnnString GHC.AnnOpen  "(#" -- '(#'
        printAnnString GHC.AnnClose  "#)"-- '#)'
      "[::]" -> do
        printAnnString GHC.AnnOpen  "[:" -- '[:'
        printAnnString GHC.AnnClose ":]" -- ':]'
      str ->  do
        addDeltaAnnotation GHC.AnnType
        addDeltaAnnotation GHC.AnnOpenP -- '('
        addDeltaAnnotationLs GHC.AnnBackquote 0
        addDeltaAnnotations GHC.AnnCommaTuple -- For '(,,,)'
        cnt <- countAnnsAP GHC.AnnVal
        cntT <- countAnnsAP GHC.AnnCommaTuple
        cntR <- countAnnsAP GHC.AnnRarrow
        case cnt of
          0 -> if cntT >0 || cntR >0
                 then return ()
                 else printAnnStringExt l GHC.AnnVal str
          1 -> printAnnString GHC.AnnVal str
          x -> error $ "annotateP.RdrName: too many AnnVal :" ++ showGhc (l,x)
        addDeltaAnnotation GHC.AnnTildehsh
        addDeltaAnnotation GHC.AnnTilde
        addDeltaAnnotation GHC.AnnRarrow
        addDeltaAnnotationLs GHC.AnnBackquote 1
        addDeltaAnnotation GHC.AnnCloseP -- ')'

-- ---------------------------------------------------------------------

-- TODO: What is this used for? Not in ExactPrint
instance AnnotateGen GHC.Name where
  annotateG l n = do
    printAnnStringExt l GHC.AnnVal (showGhc n)

-- ---------------------------------------------------------------------

instance (GHC.DataId name,AnnotateGen name)
  => AnnotateGen (GHC.ImportDecl name) where
 annotateG _ imp@(GHC.ImportDecl _msrc (GHC.L ln _) _pkg _src _safe _qual _impl _as hiding) = do

   -- 'import' maybe_src maybe_safe optqualified maybe_pkg modid maybeas maybeimpspec
   addDeltaAnnotation GHC.AnnImport

   -- "{-# SOURCE" and "#-}"
   printAnnString GHC.AnnOpen "{-# SOURCE"
   printAnnString GHC.AnnClose "#-}"
   addDeltaAnnotation GHC.AnnSafe
   addDeltaAnnotation GHC.AnnQualified
   addDeltaAnnotation GHC.AnnPackageName

   printAnnStringExt ln GHC.AnnVal (GHC.moduleNameString $ GHC.unLoc $ GHC.ideclName imp)

   case GHC.ideclAs imp of
      Nothing -> return ()
      Just mn -> do
          addDeltaAnnotation GHC.AnnAs
          printAnnString GHC.AnnVal (GHC.moduleNameString mn)

   case hiding of
     Nothing -> return ()
     Just (_isHiding,lie) -> do
       addDeltaAnnotation GHC.AnnHiding
       annotatePC lie

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
  => AnnotateGen (GHC.HsDecl name) where
  annotateG l decl = do
    case decl of
      GHC.TyClD d       -> annotateG l d
      GHC.InstD d       -> annotateG l d
      GHC.DerivD d      -> annotateG l d
      GHC.ValD d        -> annotateG l d
      GHC.SigD d        -> annotateG l d
      GHC.DefD d        -> annotateG l d
      GHC.ForD d        -> annotateG l d
      GHC.WarningD d    -> annotateG l d
      GHC.AnnD d        -> annotateG l d
      GHC.RuleD d       -> annotateG l d
      GHC.VectD d       -> annotateG l d
      GHC.SpliceD d     -> annotateG l d
      GHC.DocD d        -> annotateG l d
      GHC.QuasiQuoteD d -> annotateG l d
      GHC.RoleAnnotD d  -> annotateG l d

-- ---------------------------------------------------------------------

instance (AnnotateGen name)
   => AnnotateGen (GHC.RoleAnnotDecl name) where
  annotateG _ (GHC.RoleAnnotDecl ln mr) = do
    addDeltaAnnotation GHC.AnnType
    addDeltaAnnotation GHC.AnnRole
    annotatePC ln
    mapM_ annotatePC mr

instance AnnotateGen (Maybe GHC.Role) where
  annotateG _ Nothing  = printAnnString GHC.AnnVal "_"
  annotateG l (Just r) = printAnnStringExt l GHC.AnnVal (GHC.unpackFS $ GHC.fsFromRole r)

-- ---------------------------------------------------------------------

instance (AnnotateGen name)
   => AnnotateGen (GHC.HsQuasiQuote name) where
  annotateG _ (GHC.HsQuasiQuote _n _ss _fs) = assert False undefined

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.SpliceDecl name) where
  annotateG _ (GHC.SpliceDecl (GHC.L _ (GHC.HsSplice _n e)) flag) = do
    case flag of
      GHC.ExplicitSplice ->
        printAnnString GHC.AnnOpen "$("
      GHC.ImplicitSplice ->
        printAnnString GHC.AnnOpen "$$("
    annotatePC e
    printAnnString GHC.AnnClose ")"

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.VectDecl name) where
  annotateG _ (GHC.HsVect _src ln e) = do
    printAnnString GHC.AnnOpen "{-# VECTORISE" -- "{-# VECTORISE"
    annotatePC ln
    addDeltaAnnotation GHC.AnnEqual
    annotatePC e
    printAnnString GHC.AnnClose "#-}" -- "#-}"

  annotateG _ (GHC.HsNoVect _src ln) = do
    printAnnString GHC.AnnOpen "{-# NOVECTORISE" -- "{-# NOVECTORISE"
    annotatePC ln
    printAnnString GHC.AnnClose "#-}" -- "#-}"

  annotateG _ (GHC.HsVectTypeIn src _b ln mln) = do
    printAnnString GHC.AnnOpen src -- "{-# VECTORISE" or "{-# VECTORISE SCALAR"
    addDeltaAnnotation GHC.AnnType
    annotatePC ln
    addDeltaAnnotation GHC.AnnEqual
    annotateMaybe mln
    printAnnString GHC.AnnClose "#-}" -- "#-}"

  annotateG _ (GHC.HsVectTypeOut {}) = error $ "annotateP.HsVectTypeOut: only valid after type checker"

  annotateG _ (GHC.HsVectClassIn _src ln) = do
    printAnnString GHC.AnnOpen "{-# VECTORISE"-- "{-# VECTORISE"
    addDeltaAnnotation GHC.AnnClass
    annotatePC ln
    printAnnString GHC.AnnClose "#-}" -- "#-}"

  annotateG _ (GHC.HsVectClassOut {}) = error $ "annotateP.HsVectClassOut: only valid after type checker"
  annotateG _ (GHC.HsVectInstIn {})   = error $ "annotateP.HsVectInstIn: not supported?"
  annotateG _ (GHC.HsVectInstOut {})   = error $ "annotateP.HsVectInstOut: not supported?"

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.RuleDecls name) where
   annotateG _ (GHC.HsRules src rules) = do
     printAnnString GHC.AnnOpen src
     mapM_ annotatePC rules
     printAnnString GHC.AnnClose "#-}"

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.RuleDecl name) where
  annotateG _ (GHC.HsRule ln act bndrs lhs _ rhs _) = do
    annotatePC ln
    -- activation
    addDeltaAnnotation GHC.AnnOpenS -- "["
    addDeltaAnnotation GHC.AnnTilde
    case act of
      GHC.ActiveBefore n -> printAnnString GHC.AnnVal (show n)
      GHC.ActiveAfter n  -> printAnnString GHC.AnnVal (show n)
      _                  -> return ()
    addDeltaAnnotation GHC.AnnCloseS -- "]"

    addDeltaAnnotation GHC.AnnForall
    mapM_ annotatePC bndrs
    addDeltaAnnotation GHC.AnnDot

    annotatePC lhs
    addDeltaAnnotation GHC.AnnEqual
    annotatePC rhs

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.RuleBndr name) where
  annotateG _ (GHC.RuleBndr ln) = annotatePC ln
  annotateG _ (GHC.RuleBndrSig ln (GHC.HsWB thing _ _ _)) = do
    addDeltaAnnotation GHC.AnnOpenP -- "("
    annotatePC ln
    addDeltaAnnotation GHC.AnnDcolon
    annotatePC thing
    addDeltaAnnotation GHC.AnnCloseP -- ")"

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.AnnDecl name) where
   annotateG _ (GHC.HsAnnotation _src prov e) = do
     printAnnString GHC.AnnOpen "{-# Ann" -- "{-# Ann"
     addDeltaAnnotation GHC.AnnType
     addDeltaAnnotation GHC.AnnModule
     case prov of
       (GHC.ValueAnnProvenance n) -> annotatePC n
       (GHC.TypeAnnProvenance n) -> annotatePC n
       (GHC.ModuleAnnProvenance) -> return ()

     annotatePC e
     printAnnString GHC.AnnClose "#-}"

-- ---------------------------------------------------------------------

instance AnnotateGen name => AnnotateGen (GHC.WarnDecls name) where
   annotateG _ (GHC.Warnings src warns) = do
     printAnnString GHC.AnnOpen src
     mapM_ annotatePC warns
     printAnnString GHC.AnnClose "#-}"

-- ---------------------------------------------------------------------

instance (AnnotateGen name)
   => AnnotateGen (GHC.WarnDecl name) where
   annotateG _ (GHC.Warning lns txt) = do
     mapM_ annotatePC lns
     addDeltaAnnotation GHC.AnnOpenS -- "["
     case txt of
       GHC.WarningTxt    _src ls -> mapM_ annotatePC ls
       GHC.DeprecatedTxt _src ls -> mapM_ annotatePC ls
     addDeltaAnnotation GHC.AnnCloseS -- "]"

instance AnnotateGen GHC.FastString where
  annotateG l fs = printAnnStringExt l GHC.AnnVal (GHC.unpackFS fs)

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.ForeignDecl name) where

  annotateG _ (GHC.ForeignImport ln typ _
               (GHC.CImport cconv safety@(GHC.L ll _) _mh _imp (GHC.L ls src))) = do
    addDeltaAnnotation GHC.AnnForeign
    addDeltaAnnotation GHC.AnnImport
    annotatePC cconv
    if ll == GHC.noSrcSpan
      then return ()
      else annotatePC safety
    -- annotateMaybe mh
    printAnnStringExt ls GHC.AnnVal src
    annotatePC ln
    addDeltaAnnotation GHC.AnnDcolon
    annotatePC typ


  annotateG _l (GHC.ForeignExport ln typ _ (GHC.CExport spec (GHC.L ls src))) = do
    addDeltaAnnotation GHC.AnnForeign
    addDeltaAnnotation GHC.AnnExport
    annotatePC spec
    printAnnStringExt ls GHC.AnnVal src
    annotatePC ln
    addDeltaAnnotation GHC.AnnDcolon
    annotatePC typ


-- ---------------------------------------------------------------------

instance (AnnotateGen GHC.CExportSpec) where
  annotateG l (GHC.CExportStatic _ cconv) = annotateG l cconv

-- ---------------------------------------------------------------------

instance (AnnotateGen GHC.CCallConv) where
  annotateG l GHC.StdCallConv        =  printAnnStringExt l GHC.AnnVal "stdcall"
  annotateG l GHC.CCallConv          =  printAnnStringExt l GHC.AnnVal "ccall"
  annotateG l GHC.CApiConv           =  printAnnStringExt l GHC.AnnVal "capi"
  annotateG l GHC.PrimCallConv       =  printAnnStringExt l GHC.AnnVal "prim"
  annotateG l GHC.JavaScriptCallConv =  printAnnStringExt l GHC.AnnVal "javascript"

-- ---------------------------------------------------------------------

instance (AnnotateGen GHC.Safety) where
  annotateG l GHC.PlayRisky         = printAnnStringExt l GHC.AnnVal "unsafe"
  annotateG l GHC.PlaySafe          = printAnnStringExt l GHC.AnnVal "safe"
  annotateG l GHC.PlayInterruptible = printAnnStringExt l GHC.AnnVal "interruptible"

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.DerivDecl name) where

  annotateG _ (GHC.DerivDecl typ mov) = do
    addDeltaAnnotation GHC.AnnDeriving
    addDeltaAnnotation GHC.AnnInstance
    annotateMaybe mov
    annotatePC typ

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.DefaultDecl name) where

  annotateG _ (GHC.DefaultDecl typs) = do
    addDeltaAnnotation GHC.AnnDefault
    addDeltaAnnotation GHC.AnnOpenP -- '('
    mapM_ annotatePC typs
    addDeltaAnnotation GHC.AnnCloseP -- ')'

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.InstDecl name) where

  annotateG l (GHC.ClsInstD      cid) = annotateG l  cid
  annotateG l (GHC.DataFamInstD dfid) = annotateG l dfid
  annotateG l (GHC.TyFamInstD   tfid) = annotateG l tfid

-- ---------------------------------------------------------------------

instance AnnotateGen GHC.OverlapMode where
  annotateG _ (GHC.NoOverlap src) = do
    printAnnString GHC.AnnOpen src
    printAnnString GHC.AnnClose "#-}"

  annotateG _ (GHC.Overlappable src) = do
    printAnnString GHC.AnnOpen src
    printAnnString GHC.AnnClose "#-}"

  annotateG _ (GHC.Overlapping src) = do
    printAnnString GHC.AnnOpen src
    printAnnString GHC.AnnClose "#-}"

  annotateG _ (GHC.Overlaps src) = do
    printAnnString GHC.AnnOpen src
    printAnnString GHC.AnnClose "#-}"

  annotateG _ (GHC.Incoherent src) = do
    printAnnString GHC.AnnOpen src
    printAnnString GHC.AnnClose "#-}"

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.ClsInstDecl name) where

  annotateG _ (GHC.ClsInstDecl poly binds sigs tyfams datafams mov) = do
    addDeltaAnnotation GHC.AnnInstance
    annotateMaybe mov
    annotatePC poly
    addDeltaAnnotation GHC.AnnWhere
    addDeltaAnnotation GHC.AnnOpenC -- '{'
    addDeltaAnnotationsInside GHC.AnnSemi

    -- AZ:Need to turn this into a located list annotation.
    -- must merge all the rest
    applyListAnnotations (prepareListAnnotation (GHC.bagToList binds)
                       ++ prepareListAnnotation sigs
                       ++ prepareListAnnotation tyfams
                       ++ prepareListAnnotation datafams
                         )

    addDeltaAnnotation GHC.AnnCloseC -- '}'

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.TyFamInstDecl name) where

  annotateG _ (GHC.TyFamInstDecl eqn _) = do
    addDeltaAnnotation GHC.AnnType
    addDeltaAnnotation GHC.AnnInstance
    annotatePC eqn

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.DataFamInstDecl name) where

  annotateG l (GHC.DataFamInstDecl ln (GHC.HsWB pats _ _ _) defn _) = do
    addDeltaAnnotation GHC.AnnData
    addDeltaAnnotation GHC.AnnNewtype
    addDeltaAnnotation GHC.AnnInstance
    annotatePC ln
    mapM_ annotatePC pats
    addDeltaAnnotation GHC.AnnWhere
    addDeltaAnnotation GHC.AnnEqual
    annotateDataDefn l defn

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name) =>
                                                  AnnotateGen (GHC.HsBind name) where
  annotateG _ (GHC.FunBind (GHC.L _ln _n) _ (GHC.MG matches _ _ _) _ _ _) = do
    mapM_ annotatePC matches

  annotateG _ (GHC.PatBind lhs (GHC.GRHSs grhs lb) _typ _fvs _ticks) = do
    annotatePC lhs
    addDeltaAnnotation GHC.AnnEqual
    mapM_ annotatePC grhs
    addDeltaAnnotation GHC.AnnWhere

    -- TODO: Store the following SrcSpan in an AnnList instance for exactPC
    annotatePC (GHC.L (getLocalBindsSrcSpan lb) lb)

  annotateG _ (GHC.VarBind _n rhse _) =
    -- Note: this bind is introduced by the typechecker
    annotatePC rhse

  annotateG l (GHC.PatSynBind (GHC.PSB ln _fvs args def dir)) = do
    addDeltaAnnotation GHC.AnnPattern
    annotatePC ln
    case args of
      GHC.InfixPatSyn la lb -> do
        annotatePC la
        annotatePC lb
      GHC.PrefixPatSyn ns -> do
        mapM_ annotatePC ns
    addDeltaAnnotation GHC.AnnEqual
    addDeltaAnnotation GHC.AnnLarrow
    annotatePC def
    case dir of
      GHC.Unidirectional           -> return ()
      GHC.ImplicitBidirectional    -> return ()
      GHC.ExplicitBidirectional mg -> annotateMatchGroup l mg

    addDeltaAnnotation GHC.AnnWhere
    addDeltaAnnotation GHC.AnnOpenC  -- '{'
    addDeltaAnnotation GHC.AnnCloseC -- '}'

    return ()

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
    => AnnotateGen (GHC.IPBind name) where
  annotateG _ (GHC.IPBind en e) = do
    case en of
      Left n -> annotatePC n
      Right _i -> error $ "annotateP.IPBind:should not happen"
    addDeltaAnnotation GHC.AnnEqual
    annotatePC e

-- ---------------------------------------------------------------------

instance AnnotateGen GHC.HsIPName where
  annotateG l (GHC.HsIPName n) = printAnnStringExt l GHC.AnnVal ("?" ++ (GHC.unpackFS n))

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name,
                                                  AnnotateGen body)
  => AnnotateGen (GHC.Match name (GHC.Located body)) where

  annotateG _ (GHC.Match mln pats _typ (GHC.GRHSs grhs lb)) = do
    let
      get_infix Nothing = False
      get_infix (Just (_,f)) = f
    case (get_infix mln,pats) of
      (True,[a,b]) -> do
        annotatePC a
        case mln of
          Nothing -> do
            printAnnString GHC.AnnOpen "`" -- possible '`'
            addDeltaAnnotation GHC.AnnFunId
            printAnnString GHC.AnnClose "`"-- possible '`'
          Just (n,_) -> annotatePC n
        annotatePC b
      _ -> do
        case mln of
          Nothing -> addDeltaAnnotation GHC.AnnFunId
          Just (n,_) -> annotatePC n
        mapM_ annotatePC pats

    addDeltaAnnotation GHC.AnnEqual
    addDeltaAnnotation GHC.AnnRarrow -- For HsLam

    mapM_ annotatePC grhs

    addDeltaAnnotation GHC.AnnWhere
    addDeltaAnnotation GHC.AnnOpenC -- '{'
    addDeltaAnnotationsInside GHC.AnnSemi
    -- annotateHsLocalBinds lb
    annotateWithLayout (GHC.L (getLocalBindsSrcSpan lb) lb)
    addDeltaAnnotation GHC.AnnCloseC -- '}'

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name,
                                                  AnnotateGen body)
  => AnnotateGen (GHC.GRHS name (GHC.Located body)) where
  annotateG _ (GHC.GRHS guards expr) = do

    addDeltaAnnotation GHC.AnnVbar
    mapM_ annotatePC guards
    addDeltaAnnotation GHC.AnnEqual
    addDeltaAnnotation GHC.AnnRarrow -- in case alts
    annotatePC expr

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
  => AnnotateGen (GHC.Sig name) where

  annotateG _ (GHC.TypeSig lns typ _) = do
    mapM_ annotatePC lns
    addDeltaAnnotation GHC.AnnDcolon
    annotatePC typ

  annotateG _ (GHC.PatSynSig ln (_,GHC.HsQTvs _ns bndrs) ctx1 ctx2 typ) = do
    addDeltaAnnotation GHC.AnnPattern
    annotatePC ln
    addDeltaAnnotation GHC.AnnDcolon

    -- Note: The 'forall' bndrs '.' may occur multiple times
    addDeltaAnnotation GHC.AnnForall
    mapM_ annotatePC bndrs
    addDeltaAnnotation GHC.AnnDot

    annotatePC ctx1
    addDeltaAnnotationLs GHC.AnnDarrow 0
    annotatePC ctx2
    addDeltaAnnotationLs GHC.AnnDarrow 1
    annotatePC typ


  annotateG _ (GHC.GenericSig ns typ) = do
    addDeltaAnnotation GHC.AnnDefault
    mapM_ annotatePC ns
    addDeltaAnnotation GHC.AnnDcolon
    annotatePC typ

  annotateG _ (GHC.IdSig _) = return ()

  -- FixSig (FixitySig name)
  annotateG _ (GHC.FixSig (GHC.FixitySig lns (GHC.Fixity v fdir))) = do
    let fixstr = case fdir of
         GHC.InfixL -> "infixl"
         GHC.InfixR -> "infixr"
         GHC.InfixN -> "infix"
    printAnnString GHC.AnnInfix fixstr
    printAnnString GHC.AnnVal (show v)
    mapM_ annotatePC lns

  -- InlineSig (Located name) InlinePragma
  -- '{-# INLINE' activation qvar '#-}'
  annotateG _ (GHC.InlineSig ln inl) = do
    let actStr = case GHC.inl_act inl of
          GHC.NeverActive -> ""
          GHC.AlwaysActive -> ""
          GHC.ActiveBefore np -> show np
          GHC.ActiveAfter  np -> show np
    printAnnString GHC.AnnOpen  "{-# INLINE"  -- '{-# INLINE'
    addDeltaAnnotation GHC.AnnOpenS  -- '['
    addDeltaAnnotation  GHC.AnnTilde -- ~
    printAnnString  GHC.AnnVal actStr -- e.g. 34
    addDeltaAnnotation GHC.AnnCloseS -- ']'
    annotatePC ln
    printAnnString GHC.AnnClose "#-}" -- '#-}'


  annotateG _ (GHC.SpecSig ln typs _inl) = do
    printAnnString GHC.AnnOpen "{-# SPECIALISE" -- '{-# SPECIALISE'
    addDeltaAnnotation GHC.AnnOpenS --  '['
    addDeltaAnnotation GHC.AnnTilde -- ~
    printAnnString GHC.AnnVal  "TODO: What here"

    addDeltaAnnotation GHC.AnnCloseS -- ']'
    annotatePC ln
    addDeltaAnnotation GHC.AnnDcolon -- '::'
    mapM_ annotatePC typs
    printAnnString GHC.AnnClose "#-}" -- '#-}'


  -- '{-# SPECIALISE' 'instance' inst_type '#-}'
  annotateG _ (GHC.SpecInstSig _ typ) = do
    printAnnString GHC.AnnOpen "{-# SPECIALISE"
    addDeltaAnnotation GHC.AnnInstance
    annotatePC typ
    printAnnString GHC.AnnClose "#-}" -- '#-}'


  -- MinimalSig (BooleanFormula (Located name))
  annotateG _ (GHC.MinimalSig _ formula) = do
    printAnnString GHC.AnnOpen "{-# MINIMAL"
    annotateBooleanFormula formula
    printAnnString GHC.AnnClose "#-}"


-- ---------------------------------------------------------------------

annotateBooleanFormula :: GHC.BooleanFormula (GHC.Located name) -> Wrapped ()
annotateBooleanFormula = assert False undefined

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name) =>
                     AnnotateGen (GHC.HsTyVarBndr name) where
  annotateG l (GHC.UserTyVar n) = do
    annotateG l n

  annotateG _ (GHC.KindedTyVar n ty) = do
    addDeltaAnnotation GHC.AnnOpenP  -- '('
    annotatePC n
    addDeltaAnnotation GHC.AnnDcolon -- '::'
    annotatePC ty
    addDeltaAnnotation GHC.AnnCloseP -- '('

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.HsType name) where

  annotateG _ (GHC.HsForAllTy _f mwc (GHC.HsQTvs _kvs tvs) ctx@(GHC.L lc ctxs) typ) = do
    addDeltaAnnotation GHC.AnnOpenP -- "("
    addDeltaAnnotation GHC.AnnForall
    mapM_ annotatePC tvs
    addDeltaAnnotation GHC.AnnDot

    case mwc of
      Nothing -> if lc /= GHC.noSrcSpan then annotatePC ctx else return ()
      Just lwc -> annotatePC (GHC.L lc (GHC.sortLocated ((GHC.L lwc GHC.HsWildcardTy):ctxs)))

    addDeltaAnnotation GHC.AnnDarrow
    annotatePC typ
    addDeltaAnnotation GHC.AnnCloseP -- ")"

  annotateG l (GHC.HsTyVar n) = do
    addDeltaAnnotation GHC.AnnDcolon -- for HsKind, alias for HsType
    annotateG l n

  annotateG _ (GHC.HsAppTy t1 t2) = do
    addDeltaAnnotation GHC.AnnDcolon -- for HsKind, alias for HsType
    annotatePC t1
    annotatePC t2

  annotateG _ (GHC.HsFunTy t1 t2) = do
    addDeltaAnnotation GHC.AnnDcolon -- for HsKind, alias for HsType
    annotatePC t1
    addDeltaAnnotation GHC.AnnRarrow
    annotatePC t2

  annotateG _ (GHC.HsListTy t) = do
    addDeltaAnnotation GHC.AnnDcolon -- for HsKind, alias for HsType
    addDeltaAnnotation GHC.AnnOpenS -- '['
    annotatePC t
    addDeltaAnnotation GHC.AnnCloseS -- ']'

  annotateG _ (GHC.HsPArrTy t) = do
    printAnnString GHC.AnnOpen "[:" -- '[:'
    annotatePC t
    printAnnString GHC.AnnClose ":]" -- ':]'

  annotateG _ (GHC.HsTupleTy _tt ts) = do
    addDeltaAnnotation GHC.AnnDcolon -- for HsKind, alias for HsType
    printAnnString GHC.AnnOpen "(#" -- '(#'
    addDeltaAnnotation GHC.AnnOpenP  -- '('
    mapM_ annotatePC ts
    addDeltaAnnotation GHC.AnnCloseP -- ')'
    printAnnString GHC.AnnClose "#)" --  '#)'

  annotateG _ (GHC.HsOpTy t1 (_,lo) t2) = do
    annotatePC t1
    annotatePC lo
    annotatePC t2

  annotateG _ (GHC.HsParTy t) = do
    addDeltaAnnotation GHC.AnnDcolon -- for HsKind, alias for HsType
    addDeltaAnnotation GHC.AnnOpenP  -- '('
    annotatePC t
    addDeltaAnnotation GHC.AnnCloseP -- ')'

  annotateG l (GHC.HsIParamTy n t) = do
    annotateG l n
    addDeltaAnnotation GHC.AnnDcolon
    annotatePC t

  annotateG _ (GHC.HsEqTy t1 t2) = do
    annotatePC t1
    addDeltaAnnotation GHC.AnnTilde
    annotatePC t2

  annotateG _ (GHC.HsKindSig t k) = do
    addDeltaAnnotation GHC.AnnOpenP  -- '('
    annotatePC t
    addDeltaAnnotation GHC.AnnDcolon -- '::'
    annotatePC k
    addDeltaAnnotation GHC.AnnCloseP -- ')'

  -- HsQuasiQuoteTy (HsQuasiQuote name)
  -- TODO: Probably wrong
  annotateG l (GHC.HsQuasiQuoteTy (GHC.HsQuasiQuote n _ss q)) = do
    printAnnStringExt l GHC.AnnVal
      ("[" ++ (showGhc n) ++ "|" ++ (GHC.unpackFS q) ++ "|]")

  -- HsSpliceTy (HsSplice name) (PostTc name Kind)
  annotateG _ (GHC.HsSpliceTy (GHC.HsSplice _is e) _) = do
    printAnnString GHC.AnnOpen "$(" -- '$('
    annotatePC e
    printAnnString GHC.AnnClose ")" -- ')'

  annotateG _ (GHC.HsDocTy t ds) = do
    annotatePC t
    annotatePC ds

  annotateG _ (GHC.HsBangTy b t) = do
    case b of
      (GHC.HsSrcBang ms (Just True) _) -> do
        printAnnString GHC.AnnOpen  (maybe "{-# UNPACK" id ms)
        printAnnString GHC.AnnClose "#-}"
      (GHC.HsSrcBang ms (Just False) _) -> do
        printAnnString GHC.AnnOpen  (maybe "{-# NOUNPACK" id ms)
        printAnnString GHC.AnnClose "#-}"
      _ -> return ()
    addDeltaAnnotation GHC.AnnBang
    annotatePC t

  -- HsRecTy [LConDeclField name]
  annotateG _ (GHC.HsRecTy cons) = do
    addDeltaAnnotation GHC.AnnOpenC  -- '{'
    mapM_ annotatePC cons
    addDeltaAnnotation GHC.AnnCloseC -- '}'

  -- HsCoreTy Type
  annotateG _ (GHC.HsCoreTy _t) = return ()

  annotateG _ (GHC.HsExplicitListTy _ ts) = do
    -- TODO: what about SIMPLEQUOTE?
    printAnnString GHC.AnnOpen "'[" -- "'["
    mapM_ annotatePC ts
    addDeltaAnnotation GHC.AnnCloseS -- ']'

  annotateG _ (GHC.HsExplicitTupleTy _ ts) = do
    printAnnString GHC.AnnOpen "'(" -- "'("
    mapM_ annotatePC ts
    printAnnString GHC.AnnClose ")" -- ')'

  -- HsTyLit HsTyLit
  annotateG l (GHC.HsTyLit lit) = do
    case lit of
      (GHC.HsNumTy s _) ->
        printAnnStringExt l GHC.AnnVal s
      (GHC.HsStrTy s _) ->
        printAnnStringExt l GHC.AnnVal s

  -- HsWrapTy HsTyWrapped (HsType name)
  annotateG _ (GHC.HsWrapTy _ _) = return ()

  annotateG l (GHC.HsWildcardTy) = do
    printAnnStringExt l GHC.AnnVal "_"
    addDeltaAnnotation GHC.AnnDarrow -- if only part of a partial type signature context
-- TODO: Probably wrong
  annotateG l (GHC.HsNamedWildcardTy n) = do
    printAnnStringExt l GHC.AnnVal  (showGhc n)

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name) =>
                             AnnotateGen (GHC.ConDeclField name) where
  annotateG _ (GHC.ConDeclField ns ty mdoc) = do
    mapM_ annotatePC ns
    addDeltaAnnotation GHC.AnnDcolon
    annotatePC ty
    annotateMaybe mdoc

-- ---------------------------------------------------------------------

instance AnnotateGen GHC.HsDocString where
  annotateG l (GHC.HsDocString s) = do
    printAnnStringExt l GHC.AnnVal (GHC.unpackFS s)

-- ---------------------------------------------------------------------

instance (GHC.DataId name,AnnotateGen name,GHC.OutputableBndr name)
  => AnnotateGen (GHC.Pat name) where
  annotateG l (GHC.WildPat _) = printAnnStringExt l GHC.AnnVal "_"
  -- TODO: probably wrong
  annotateG l (GHC.VarPat n)  = printAnnStringExt l GHC.AnnVal (showGhc n)
  annotateG _ (GHC.LazyPat p) = do
    addDeltaAnnotation GHC.AnnTilde
    annotatePC p

  annotateG _ (GHC.AsPat ln p) = do
    annotatePC ln
    addDeltaAnnotation GHC.AnnAt
    annotatePC p

  annotateG _ (GHC.ParPat p) = do
    addDeltaAnnotation GHC.AnnOpenP
    annotatePC p
    addDeltaAnnotation GHC.AnnCloseP

  annotateG _ (GHC.BangPat p) = do
    addDeltaAnnotation GHC.AnnBang
    annotatePC p

  annotateG _ (GHC.ListPat ps _ _) = do
    addDeltaAnnotation GHC.AnnOpenS
    mapM_ annotatePC ps
    addDeltaAnnotation GHC.AnnCloseS

  annotateG _ (GHC.TuplePat pats b _) = do
    if b == GHC.Boxed then addDeltaAnnotation GHC.AnnOpenP
                      else printAnnString GHC.AnnOpen "(#"
    mapM_ annotatePC pats
    if b == GHC.Boxed then addDeltaAnnotation GHC.AnnCloseP
                      else printAnnString GHC.AnnClose "#)"

  annotateG _ (GHC.PArrPat ps _) = do
    printAnnString GHC.AnnOpen "[:"
    mapM_ annotatePC ps
    printAnnString GHC.AnnClose ":]"

  annotateG _ (GHC.ConPatIn n dets) = do
    annotateHsConPatDetails n dets

  annotateG _ (GHC.ConPatOut {}) = return ()

  -- ViewPat (LHsExpr id) (LPat id) (PostTc id Type)
  annotateG _ (GHC.ViewPat e pat _) = do
    annotatePC e
    addDeltaAnnotation GHC.AnnRarrow
    annotatePC pat

  -- SplicePat (HsSplice id)
  annotateG _ (GHC.SplicePat (GHC.HsSplice _ e)) = do
    printAnnString GHC.AnnOpen "$(" -- '$('
    annotatePC e
    printAnnString GHC.AnnClose ")" -- ')'

  -- QuasiQuotePat (HsQuasiQuote id)
  -- TODO
  annotateG l (GHC.QuasiQuotePat (GHC.HsQuasiQuote n _ q)) = do
    printAnnStringExt l GHC.AnnVal
      ("[" ++ (showGhc n) ++ "|" ++ (GHC.unpackFS q) ++ "|]")

  -- LitPat HsLit
  annotateG l (GHC.LitPat lp) = printAnnStringExt l GHC.AnnVal (hsLit2String lp)

  -- NPat (HsOverLit id) (Maybe (SyntaxExpr id)) (SyntaxExpr id)
  annotateG _ (GHC.NPat ol _ _) = do
    addDeltaAnnotation GHC.AnnMinus
    annotatePC ol

  -- NPlusKPat (Located id) (HsOverLit id) (SyntaxExpr id) (SyntaxExpr id)
  annotateG _ (GHC.NPlusKPat ln ol _ _) = do
    annotatePC ln
    printAnnString GHC.AnnVal "+"  -- "+"
    annotatePC ol

  annotateG l (GHC.SigPatIn pat ty) = do
    annotatePC pat
    addDeltaAnnotation GHC.AnnDcolon
    annotateG l ty

  annotateG _ (GHC.SigPatOut {}) = return ()

  -- CoPat HsWrapped (Pat id) Type
  annotateG _ (GHC.CoPat {}) = return ()

-- ---------------------------------------------------------------------
hsLit2String :: GHC.HsLit -> GHC.SourceText
hsLit2String lit =
  case lit of
    GHC.HsChar       src _   -> src
    GHC.HsCharPrim   src _   -> src
    GHC.HsString     src _   -> src
    GHC.HsStringPrim src _   -> src
    GHC.HsInt        src _   -> src
    GHC.HsIntPrim    src _   -> src
    GHC.HsWordPrim   src _   -> src
    GHC.HsInt64Prim  src _   -> src
    GHC.HsWord64Prim src _   -> src
    GHC.HsInteger    src _ _ -> src
    GHC.HsRat        (GHC.FL src _) _ -> src
    GHC.HsFloatPrim  (GHC.FL src _)   -> src
    GHC.HsDoublePrim (GHC.FL src _)   -> src

annotateHsConPatDetails :: (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
                      => GHC.Located name -> GHC.HsConPatDetails name -> Wrapped ()
annotateHsConPatDetails ln dets = do
  case dets of
    GHC.PrefixCon args -> do
      annotatePC ln
      mapM_ annotatePC args
    GHC.RecCon (GHC.HsRecFields fs _) -> do
      annotatePC ln
      addDeltaAnnotation GHC.AnnOpenC -- '{'
      mapM_ annotatePC fs
      addDeltaAnnotation GHC.AnnDotdot
      addDeltaAnnotation GHC.AnnCloseC -- '}'
    GHC.InfixCon a1 a2 -> do
      annotatePC a1
      annotatePC ln
      annotatePC a2

annotateHsConDeclDetails :: (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
                    =>  [GHC.Located name] -> GHC.HsConDeclDetails name -> Wrapped ()
annotateHsConDeclDetails lns dets = do
  case dets of
    GHC.PrefixCon args -> mapM_ annotatePC args
    GHC.RecCon fs -> do
      addDeltaAnnotation GHC.AnnOpenC
      annotatePC fs
      addDeltaAnnotation GHC.AnnCloseC
    GHC.InfixCon a1 a2 -> do
      annotatePC a1
      mapM_ annotatePC lns
      annotatePC a2

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen [GHC.LConDeclField name] where
  annotateG _ fs = do
       addDeltaAnnotation GHC.AnnOpenC -- '{'
       mapM_ annotatePC fs
       addDeltaAnnotation GHC.AnnDotdot
       addDeltaAnnotation GHC.AnnCloseC -- '}'

-- ---------------------------------------------------------------------

instance (GHC.DataId name) => AnnotateGen (GHC.HsOverLit name) where
  annotateG l ol =
    let str = case GHC.ol_val ol of
                GHC.HsIntegral src _ -> src
                GHC.HsFractional l   -> (GHC.fl_text l)
                GHC.HsIsString src _ -> src
    in
    printAnnStringExt l GHC.AnnVal str

-- ---------------------------------------------------------------------

instance (GHC.DataId name,AnnotateGen arg)
    => AnnotateGen (GHC.HsWithBndrs name (GHC.Located arg)) where
  annotateG _ (GHC.HsWB thing _ _ _) = annotatePC thing

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name,AnnotateGen body) =>
                            AnnotateGen (GHC.Stmt name (GHC.Located body)) where

  annotateG _ (GHC.LastStmt body _) = annotatePC body

  annotateG _ (GHC.BindStmt pat body _ _) = do
    annotatePC pat
    addDeltaAnnotation GHC.AnnLarrow
    annotatePC body
    addDeltaAnnotation GHC.AnnVbar -- possible in list comprehension

  annotateG _ (GHC.BodyStmt body _ _ _) = do
    annotatePC body

  annotateG _ (GHC.LetStmt lb) = do
    -- return () `debug` ("annotateP.LetStmt entered")
    addDeltaAnnotation GHC.AnnLet
    addDeltaAnnotation GHC.AnnOpenC -- '{'
    annotateWithLayout (GHC.L (getLocalBindsSrcSpan lb) lb)
    addDeltaAnnotation GHC.AnnCloseC -- '}'
    -- return () `debug` ("annotateP.LetStmt done")

  annotateG _ (GHC.ParStmt pbs _ _) = do
    mapM_ annotateParStmtBlock pbs

  annotateG _ (GHC.TransStmt form stmts _b using by _ _ _) = do
    mapM_ annotatePC stmts
    case form of
      GHC.ThenForm -> do
        addDeltaAnnotation GHC.AnnThen
        annotatePC using
        addDeltaAnnotation GHC.AnnBy
        case by of
          Just b -> annotatePC b
          Nothing -> return ()
      GHC.GroupForm -> do
        addDeltaAnnotation GHC.AnnThen
        addDeltaAnnotation GHC.AnnGroup
        addDeltaAnnotation GHC.AnnBy
        case by of
          Just b -> annotatePC b
          Nothing -> return ()
        addDeltaAnnotation GHC.AnnUsing
        annotatePC using

  annotateG _ (GHC.RecStmt stmts _ _ _ _ _ _ _ _) = do
    addDeltaAnnotation GHC.AnnRec
    addDeltaAnnotation GHC.AnnOpenC
    addDeltaAnnotationsInside GHC.AnnSemi
    mapM_ annotatePC stmts
    addDeltaAnnotation GHC.AnnCloseC

-- ---------------------------------------------------------------------

annotateParStmtBlock :: (GHC.DataId name,GHC.OutputableBndr name, AnnotateGen name)
  =>  GHC.ParStmtBlock name name -> Wrapped ()
annotateParStmtBlock (GHC.ParStmtBlock stmts _ns _) =
  mapM_ annotatePC stmts

-- ---------------------------------------------------------------------

-- | Local binds need to be indented as a group, and thus need to have a
-- SrcSpan around them so they can be processed via the normal
-- annotatePC / exactPC machinery.
getLocalBindsSrcSpan :: GHC.HsLocalBinds name -> GHC.SrcSpan
getLocalBindsSrcSpan (GHC.HsValBinds (GHC.ValBindsIn binds sigs))
  = case spans of
      []  -> GHC.noSrcSpan
      sss -> GHC.combineSrcSpans (head sss) (last sss)
  where
    spans = sort (map GHC.getLoc (GHC.bagToList binds) ++ map GHC.getLoc sigs)

getLocalBindsSrcSpan (GHC.HsValBinds (GHC.ValBindsOut {}))
   = error "getLocalBindsSrcSpan: only valid after type checking"

getLocalBindsSrcSpan (GHC.HsIPBinds (GHC.IPBinds binds _))
  = case sort (map GHC.getLoc binds) of
      [] -> GHC.noSrcSpan
      sss -> GHC.combineSrcSpans (head sss) (last sss)

getLocalBindsSrcSpan (GHC.EmptyLocalBinds) = GHC.noSrcSpan

-- ---------------------------------------------------------------------

-- | Generate a SrcSpan that enclosed the given list
getListSrcSpan :: [GHC.Located a] -> GHC.SrcSpan
getListSrcSpan ls
  = case ls of
      []  -> GHC.noSrcSpan
      sss -> GHC.combineLocs (head sss) (last sss)

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
  => AnnotateGen (GHC.HsLocalBinds name) where
  annotateG _ lb = annotateHsLocalBinds lb

-- ---------------------------------------------------------------------

annotateHsLocalBinds :: (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
                     => (GHC.HsLocalBinds name) -> Wrapped ()
annotateHsLocalBinds (GHC.HsValBinds (GHC.ValBindsIn binds sigs)) = do
    applyListAnnotations (prepareListAnnotation (GHC.bagToList binds)
                       ++ prepareListAnnotation sigs
                         )
annotateHsLocalBinds (GHC.HsValBinds (GHC.ValBindsOut {}))
   = error $ "annotateHsLocalBinds: only valid after type checking"

annotateHsLocalBinds (GHC.HsIPBinds (GHC.IPBinds binds _)) = mapM_ annotatePC binds
annotateHsLocalBinds (GHC.EmptyLocalBinds)                 = return ()

-- ---------------------------------------------------------------------

annotateMatchGroup :: (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name,
                                               AnnotateGen body)
                   => GHC.SrcSpan -> (GHC.MatchGroup name (GHC.Located body))
                   -> Wrapped ()
annotateMatchGroup l (GHC.MG matches _ _ _)
  = annotateListWithLayout l matches

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name,
                                               AnnotateGen body)
  => AnnotateGen [GHC.Located (GHC.Match name (GHC.Located body))] where
  annotateG _ ls = mapM_ annotatePC ls

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
  => AnnotateGen (GHC.HsExpr name) where
  annotateG l (GHC.HsVar n)           = annotateG l n
  annotateG l (GHC.HsIPVar (GHC.HsIPName v))         =
    printAnnStringExt l GHC.AnnVal ("?" ++ GHC.unpackFS v)
  annotateG l (GHC.HsOverLit ov)     = annotateG l ov
  annotateG l (GHC.HsLit lit)           = annotateG l lit

  annotateG l (GHC.HsLam match)       = do
    addDeltaAnnotation GHC.AnnLam
    annotateMatchGroup l match

  annotateG l (GHC.HsLamCase _ match) = annotateMatchGroup l match

  annotateG _ (GHC.HsApp e1 e2) = do
    annotatePC e1
    annotatePC e2

  annotateG _ (GHC.OpApp e1 e2 _ e3) = do
    annotatePC e1
    annotatePC e2
    annotatePC e3

  annotateG _ (GHC.NegApp e _) = do
    addDeltaAnnotation GHC.AnnMinus
    annotatePC e

  annotateG _ (GHC.HsPar e) = do
    addDeltaAnnotation GHC.AnnOpenP -- '('
    annotatePC e
    addDeltaAnnotation GHC.AnnCloseP -- ')'

  annotateG _ (GHC.SectionL e1 e2) = do
    annotatePC e1
    annotatePC e2

  annotateG _ (GHC.SectionR e1 e2) = do
    annotatePC e1
    annotatePC e2

  annotateG _ (GHC.ExplicitTuple args b) = do
    if b == GHC.Boxed then addDeltaAnnotation GHC.AnnOpenP
                      else printAnnString GHC.AnnOpen "(#"

    mapM_ annotatePC args

    if b == GHC.Boxed then addDeltaAnnotation GHC.AnnCloseP
                      else printAnnString GHC.AnnClose "#)"

  annotateG l (GHC.HsCase e1 matches) = do
    addDeltaAnnotation GHC.AnnCase
    annotatePC e1
    addDeltaAnnotation GHC.AnnOf
    addDeltaAnnotation GHC.AnnOpenC
    addDeltaAnnotationsInside GHC.AnnSemi
    annotateMatchGroup l matches
    addDeltaAnnotation GHC.AnnCloseC

  annotateG _ (GHC.HsIf _ e1 e2 e3) = do
    addDeltaAnnotation GHC.AnnIf
    annotatePC e1
    addDeltaAnnotationLs GHC.AnnSemi 0
    addDeltaAnnotation GHC.AnnThen
    annotatePC e2
    addDeltaAnnotationLs GHC.AnnSemi 1
    addDeltaAnnotation GHC.AnnElse
    annotatePC e3

  annotateG _ (GHC.HsMultiIf _ rhs) = do
    addDeltaAnnotation GHC.AnnIf
    mapM_ annotatePC rhs

  annotateG _ (GHC.HsLet binds e) = do
    setLayoutFlag -- Make sure the 'in' gets indented too
    addDeltaAnnotation GHC.AnnLet
    addDeltaAnnotation GHC.AnnOpenC
    addDeltaAnnotationsInside GHC.AnnSemi
    annotateWithLayout (GHC.L (getLocalBindsSrcSpan binds) binds)
    addDeltaAnnotation GHC.AnnCloseC
    addDeltaAnnotation GHC.AnnIn
    annotatePC e

  annotateG l (GHC.HsDo cts es _) = do
    addDeltaAnnotation GHC.AnnDo
    let (ostr,cstr,isComp) =
          if isListComp cts
            then case cts of
                   GHC.PArrComp -> ("[:",":]",True)
                   _            -> ("[",  "]",True)
            else ("{","}",False)

    printAnnString GHC.AnnOpen ostr
    addDeltaAnnotation GHC.AnnOpenS
    addDeltaAnnotation GHC.AnnOpenC
    addDeltaAnnotationsInside GHC.AnnSemi
    if isListComp cts
      then do
        annotatePC (last es)
        addDeltaAnnotation GHC.AnnVbar
        mapM_ annotatePC (init es)
      else do
        annotateListWithLayout l es
    addDeltaAnnotation GHC.AnnCloseS
    addDeltaAnnotation GHC.AnnCloseC
    printAnnString GHC.AnnClose cstr

  annotateG _ (GHC.ExplicitList _ _ es) = do
    addDeltaAnnotation GHC.AnnOpenS
    mapM_ annotatePC es
    addDeltaAnnotation GHC.AnnCloseS

  annotateG _ (GHC.ExplicitPArr _ es)   = do
    printAnnString GHC.AnnOpen "[:"
    mapM_ annotatePC es
    printAnnString GHC.AnnClose ":]"

  annotateG _ (GHC.RecordCon n _ (GHC.HsRecFields fs _)) = do
    annotatePC n
    addDeltaAnnotation GHC.AnnOpenC
    addDeltaAnnotation GHC.AnnDotdot
    mapM_ annotatePC fs
    addDeltaAnnotation GHC.AnnCloseC

  annotateG _ (GHC.RecordUpd e (GHC.HsRecFields fs _) _cons _ _) = do
    annotatePC e
    addDeltaAnnotation GHC.AnnOpenC
    addDeltaAnnotation GHC.AnnDotdot
    mapM_ annotatePC fs
    addDeltaAnnotation GHC.AnnCloseC

  annotateG _ (GHC.ExprWithTySig e typ _) = do
    annotatePC e
    addDeltaAnnotation GHC.AnnDcolon
    annotatePC typ

  annotateG _ (GHC.ExprWithTySigOut e typ) = do
    annotatePC e
    addDeltaAnnotation GHC.AnnDcolon
    annotatePC typ

  annotateG _ (GHC.ArithSeq _ _ seqInfo) = do
    addDeltaAnnotation GHC.AnnOpenS -- '['
    case seqInfo of
        GHC.From e -> do
          annotatePC e
          addDeltaAnnotation GHC.AnnDotdot
        GHC.FromTo e1 e2 -> do
          annotatePC e1
          addDeltaAnnotation GHC.AnnDotdot
          annotatePC e2
        GHC.FromThen e1 e2 -> do
          annotatePC e1
          addDeltaAnnotation GHC.AnnComma
          annotatePC e2
          addDeltaAnnotation GHC.AnnDotdot
        GHC.FromThenTo e1 e2 e3 -> do
          annotatePC e1
          addDeltaAnnotation GHC.AnnComma
          annotatePC e2
          addDeltaAnnotation GHC.AnnDotdot
          annotatePC e3
    addDeltaAnnotation GHC.AnnCloseS -- ']'

  annotateG _ (GHC.PArrSeq _ seqInfo) = do
    printAnnString GHC.AnnOpen "[:" -- '[:'
    case seqInfo of
        GHC.From e -> do
          annotatePC e
          addDeltaAnnotation GHC.AnnDotdot
        GHC.FromTo e1 e2 -> do
          annotatePC e1
          addDeltaAnnotation GHC.AnnDotdot
          annotatePC e2
        GHC.FromThen e1 e2 -> do
          annotatePC e1
          addDeltaAnnotation GHC.AnnComma
          annotatePC e2
          addDeltaAnnotation GHC.AnnDotdot
        GHC.FromThenTo e1 e2 e3 -> do
          annotatePC e1
          addDeltaAnnotation GHC.AnnComma
          annotatePC e2
          addDeltaAnnotation GHC.AnnDotdot
          annotatePC e3
    printAnnString GHC.AnnClose ":]" -- ':]'

  annotateG _ (GHC.HsSCC _ csFStr e) = do
    printAnnString GHC.AnnOpen "{-# SCC"
    printAnnString GHC.AnnVal (GHC.unpackFS csFStr)
    addDeltaAnnotation GHC.AnnValStr
    printAnnString GHC.AnnClose "#-}"
    annotatePC e

  annotateG _ (GHC.HsCoreAnn _ csFStr e) = do
    printAnnString GHC.AnnOpen "{-# CORE"
    printAnnString GHC.AnnVal (GHC.unpackFS csFStr)
    printAnnString GHC.AnnClose "#-}"
    annotatePC e
  -- TODO: make monomorphic
  annotateG l (GHC.HsBracket (GHC.VarBr single v)) =
    let str =
          if single then ("'"  ++ showGhc v)
                    else ("''" ++ showGhc v)
    in
    printAnnStringExt l GHC.AnnVal str
  annotateG _ (GHC.HsBracket (GHC.DecBrL ds)) = do
    printAnnString GHC.AnnOpen "[d|"
    addDeltaAnnotation GHC.AnnOpenC
    mapM_ annotatePC ds
    addDeltaAnnotation GHC.AnnCloseC
    printAnnString GHC.AnnClose "|]"
  annotateG _ (GHC.HsBracket (GHC.ExpBr e)) = do
    printAnnString GHC.AnnOpen "[|"
    annotatePC e
    printAnnString GHC.AnnClose "|]"
  annotateG _ (GHC.HsBracket (GHC.TExpBr e)) = do
    printAnnString GHC.AnnOpen "[||"
    annotatePC e
    printAnnString GHC.AnnClose "||]"
  annotateG _ (GHC.HsBracket (GHC.TypBr e)) = do
    printAnnString GHC.AnnOpen "[t|"
    annotatePC e
    printAnnString GHC.AnnClose "|]"
  annotateG _ (GHC.HsBracket (GHC.PatBr e)) = do
    printAnnString GHC.AnnOpen  "[p|"
    annotatePC e
    printAnnString GHC.AnnClose "|]"

  annotateG _ (GHC.HsRnBracketOut _ _) = return ()
  annotateG _ (GHC.HsTcBracketOut _ _) = return ()

  annotateG _ (GHC.HsSpliceE False (GHC.HsSplice _ e)) = do
    printAnnString GHC.AnnOpen "$("
    annotatePC e
    printAnnString GHC.AnnClose ")"

  annotateG _ (GHC.HsSpliceE True (GHC.HsSplice _ e)) = do
    printAnnString GHC.AnnOpen "$$("
    annotatePC e
    printAnnString GHC.AnnClose ")"

  annotateG l (GHC.HsQuasiQuoteE (GHC.HsQuasiQuote n _ q)) = do
    printAnnStringExt l GHC.AnnVal
      ("[" ++ (showGhc n) ++ "|" ++ (GHC.unpackFS q) ++ "|]")


  annotateG _ (GHC.HsProc p c) = do
    addDeltaAnnotation GHC.AnnProc
    annotatePC p
    addDeltaAnnotation GHC.AnnRarrow
    annotatePC c

  annotateG _ (GHC.HsStatic e) = do
    addDeltaAnnotation GHC.AnnStatic
    annotatePC e

  annotateG _ (GHC.HsArrApp e1 e2 _ _ _) = do
    annotatePC e1
    -- only one of the next 4 will be resent
    addDeltaAnnotation GHC.Annlarrowtail
    addDeltaAnnotation GHC.Annrarrowtail
    addDeltaAnnotation GHC.AnnLarrowtail
    addDeltaAnnotation GHC.AnnRarrowtail

    annotatePC e2

  annotateG _ (GHC.HsArrForm e _ cs) = do
    printAnnString GHC.AnnOpen "(|"
    annotatePC e
    mapM_ annotatePC cs
    printAnnString GHC.AnnClose "|)"

  annotateG _ (GHC.HsTick _ _) = return ()
  annotateG _ (GHC.HsBinTick _ _ _) = return ()

  annotateG _ (GHC.HsTickPragma _ (str,(v1,v2),(v3,v4)) e) = do
    -- '{-# GENERATED' STRING INTEGER ':' INTEGER '-' INTEGER ':' INTEGER '#-}'
    printAnnString       GHC.AnnOpen  "{-# GENERATED"
    printAnnStringLs GHC.AnnVal (GHC.unpackFS str) 0 -- STRING
    printAnnStringLs GHC.AnnVal (show v1)  1 -- INTEGER
    addDeltaAnnotationLs GHC.AnnColon 0 -- ':'
    printAnnStringLs GHC.AnnVal (show v2)  2 -- INTEGER
    addDeltaAnnotation   GHC.AnnMinus   -- '-'
    printAnnStringLs GHC.AnnVal (show v3)  3 -- INTEGER
    addDeltaAnnotationLs GHC.AnnColon 1 -- ':'
    printAnnStringLs GHC.AnnVal (show v4)  4 -- INTEGER
    printAnnString   GHC.AnnClose  "#-}"
    annotatePC e

  annotateG l (GHC.EWildPat) = do
    printAnnStringExt l GHC.AnnVal "_"

  annotateG _ (GHC.EAsPat ln e) = do
    annotatePC ln
    addDeltaAnnotation GHC.AnnAt
    annotatePC e

  annotateG _ (GHC.EViewPat e1 e2) = do
    annotatePC e1
    addDeltaAnnotation GHC.AnnRarrow
    annotatePC e2

  annotateG _ (GHC.ELazyPat e) = do
    addDeltaAnnotation GHC.AnnTilde
    annotatePC e

  annotateG _ (GHC.HsType ty) = annotatePC ty

  annotateG _ (GHC.HsWrap _ _) = return ()
  annotateG _ (GHC.HsUnboundVar _) = return ()

instance AnnotateGen GHC.HsLit where
  annotateG l lit = printAnnStringExt l GHC.AnnVal (hsLit2String lit)
-- ---------------------------------------------------------------------

-- |Used for declarations that need to be aligned together, e.g. in a
-- do or let .. in statement/expr
instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
  => AnnotateGen ([GHC.ExprLStmt name]) where
  annotateG _ ls = mapM_ annotatePC ls

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
  => AnnotateGen (GHC.HsTupArg name) where
  annotateG _ (GHC.Present e) = do
    annotatePC e

  annotateG _ (GHC.Missing _) = do
    addDeltaAnnotation GHC.AnnComma

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
  => AnnotateGen (GHC.HsCmdTop name) where
  annotateG _ (GHC.HsCmdTop cmd _ _ _) = annotatePC cmd

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
   => AnnotateGen (GHC.HsCmd name) where
  annotateG _ (GHC.HsCmdArrApp e1 e2 _ _ _) = do
    annotatePC e1
    -- only one of the next 4 will be resent
    addDeltaAnnotation GHC.Annlarrowtail
    addDeltaAnnotation GHC.Annrarrowtail
    addDeltaAnnotation GHC.AnnLarrowtail
    addDeltaAnnotation GHC.AnnRarrowtail

    annotatePC e2

  annotateG _ (GHC.HsCmdArrForm e _mf cs) = do
    printAnnString GHC.AnnOpen "(|"
    annotatePC e
    mapM_ annotatePC cs
    printAnnString GHC.AnnClose "|)"

  annotateG _ (GHC.HsCmdApp e1 e2) = do
    annotatePC e1
    annotatePC e2

  annotateG l (GHC.HsCmdLam match) = do
    addDeltaAnnotation GHC.AnnLam
    annotateMatchGroup l match

  annotateG _ (GHC.HsCmdPar e) = do
    addDeltaAnnotation GHC.AnnOpenP
    annotatePC e
    addDeltaAnnotation GHC.AnnCloseP -- ')'

  annotateG l (GHC.HsCmdCase e1 matches) = do
    addDeltaAnnotation GHC.AnnCase
    annotatePC e1
    addDeltaAnnotation GHC.AnnOf
    addDeltaAnnotation GHC.AnnOpenC
    annotateMatchGroup l matches
    addDeltaAnnotation GHC.AnnCloseC

  annotateG _ (GHC.HsCmdIf _ e1 e2 e3) = do
    addDeltaAnnotation GHC.AnnIf
    annotatePC e1
    addDeltaAnnotationLs GHC.AnnSemi 0
    addDeltaAnnotation GHC.AnnThen
    annotatePC e2
    addDeltaAnnotationLs GHC.AnnSemi 1
    addDeltaAnnotation GHC.AnnElse
    annotatePC e3

  annotateG _ (GHC.HsCmdLet binds e) = do
    addDeltaAnnotation GHC.AnnLet
    addDeltaAnnotation GHC.AnnOpenC
    annotateWithLayout (GHC.L (getLocalBindsSrcSpan binds) binds)
    addDeltaAnnotation GHC.AnnCloseC
    addDeltaAnnotation GHC.AnnIn
    annotatePC e

  annotateG l (GHC.HsCmdDo es _) = do
    addDeltaAnnotation GHC.AnnDo
    addDeltaAnnotation GHC.AnnOpenC
    -- mapM_ annotatePC es
    annotateListWithLayout l es
    addDeltaAnnotation GHC.AnnCloseC

  annotateG _ (GHC.HsCmdCast {}) = error $ "annotateP.HsCmdCast: only valid after type checker"


-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
  => AnnotateGen [GHC.Located (GHC.StmtLR name name (GHC.LHsCmd name))] where
  annotateG _ ls = mapM_ annotatePC ls

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
     => AnnotateGen (GHC.TyClDecl name) where

  annotateG l (GHC.FamDecl famdecl) = annotateG l famdecl

  annotateG _ (GHC.SynDecl ln (GHC.HsQTvs _ tyvars) typ _) = do
    addDeltaAnnotation GHC.AnnType
    annotatePC ln
    mapM_ annotatePC tyvars
    addDeltaAnnotation GHC.AnnEqual
    annotatePC typ

  annotateG _ (GHC.DataDecl ln (GHC.HsQTvs _ns tyVars)
                (GHC.HsDataDefn _ ctx mctyp mk cons mderivs) _) = do
    addDeltaAnnotation GHC.AnnData
    addDeltaAnnotation GHC.AnnNewtype
    annotateMaybe mctyp
    annotatePC ctx
    addDeltaAnnotation GHC.AnnDarrow
    annotateTyClass ln tyVars
    addDeltaAnnotation GHC.AnnDcolon
    annotateMaybe mk
    addDeltaAnnotation GHC.AnnEqual
    addDeltaAnnotation GHC.AnnWhere
    mapM_ annotatePC cons
    annotateMaybe mderivs

  -- -----------------------------------

  annotateG _ (GHC.ClassDecl ctx ln (GHC.HsQTvs _ns tyVars) fds
                          sigs meths ats atdefs docs _) = do
    addDeltaAnnotation GHC.AnnClass
    annotatePC ctx

    annotateTyClass ln tyVars

    addDeltaAnnotation GHC.AnnVbar
    mapM_ annotatePC fds
    addDeltaAnnotation GHC.AnnWhere
    addDeltaAnnotation GHC.AnnOpenC -- '{'
    addDeltaAnnotationsInside GHC.AnnSemi
    applyListAnnotations (prepareListAnnotation sigs
                       ++ prepareListAnnotation (GHC.bagToList meths)
                       ++ prepareListAnnotation ats
                       ++ prepareListAnnotation atdefs
                       ++ prepareListAnnotation docs
                         )
    addDeltaAnnotation GHC.AnnCloseC -- '}'

-- ---------------------------------------------------------------------

annotateTyClass :: (AnnotateGen a, AnnotateGen ast)
                => GHC.Located a -> [GHC.Located ast] -> Wrapped ()
annotateTyClass ln tyVars = do
    addDeltaAnnotations GHC.AnnOpenP
    applyListAnnotations (prepareListAnnotation [ln]
                      ++ prepareListAnnotation (take 2 tyVars))
    addDeltaAnnotations GHC.AnnCloseP
    mapM_ annotatePC (drop 2 tyVars)

-- ---------------------------------------------------------------------

instance (GHC.DataId name,AnnotateGen name, GHC.OutputableBndr name)
   => AnnotateGen (GHC.FamilyDecl name) where
  annotateG _ (GHC.FamilyDecl info ln (GHC.HsQTvs _ tyvars) mkind) = do
    addDeltaAnnotation GHC.AnnType
    addDeltaAnnotation GHC.AnnData
    addDeltaAnnotation GHC.AnnFamily
    annotatePC ln
    mapM_ annotatePC tyvars
    addDeltaAnnotation GHC.AnnDcolon
    annotateMaybe mkind
    addDeltaAnnotation GHC.AnnWhere
    addDeltaAnnotation GHC.AnnOpenC -- {
    case info of
      GHC.ClosedTypeFamily eqns -> mapM_ annotatePC eqns
      _ -> return ()
    case info of
      GHC.ClosedTypeFamily eqns -> mapM_ annotatePC eqns
      _ -> return ()
    addDeltaAnnotation GHC.AnnCloseC -- }

-- ---------------------------------------------------------------------

instance (GHC.DataId name,AnnotateGen name,GHC.OutputableBndr name)
   => AnnotateGen (GHC.TyFamInstEqn name) where
  annotateG _ (GHC.TyFamEqn ln (GHC.HsWB pats _ _ _) typ) = do
    annotatePC ln
    mapM_ annotatePC pats
    addDeltaAnnotation GHC.AnnEqual
    annotatePC typ


-- ---------------------------------------------------------------------

instance (GHC.DataId name,AnnotateGen name,GHC.OutputableBndr name)
  => AnnotateGen (GHC.TyFamDefltEqn name) where
  annotateG _ (GHC.TyFamEqn ln (GHC.HsQTvs _ns bndrs) typ) = do
    annotatePC ln
    mapM_ annotatePC bndrs
    addDeltaAnnotation GHC.AnnEqual
    annotatePC typ

-- ---------------------------------------------------------------------

-- TODO: modify lexer etc, in the meantime to not set haddock flag
instance AnnotateGen GHC.DocDecl where
  annotateG l v =
    let str =
          case v of
            (GHC.DocCommentNext (GHC.HsDocString fs)) -> (GHC.unpackFS fs)
            (GHC.DocCommentPrev (GHC.HsDocString fs)) -> (GHC.unpackFS fs)
            (GHC.DocCommentNamed _s (GHC.HsDocString fs)) -> (GHC.unpackFS fs)
            (GHC.DocGroup _i (GHC.HsDocString fs)) -> (GHC.unpackFS fs)
    in
      printAnnStringExt l (GHC.AnnVal) str

-- ---------------------------------------------------------------------

annotateDataDefn :: (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
  => GHC.SrcSpan -> GHC.HsDataDefn name -> Wrapped ()
annotateDataDefn _ (GHC.HsDataDefn _ ctx typ mk cons mderivs) = do
  annotatePC ctx
  annotateMaybe typ
  annotateMaybe mk
  mapM_ annotatePC cons
  case mderivs of
    Nothing -> return ()
    Just d -> annotatePC d

-- ---------------------------------------------------------------------

-- Note: GHC.HsContext name aliases to here too
instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name)
     => AnnotateGen [GHC.LHsType name] where
  annotateG l ts = do
    return () `debug` ("annotateP.HsContext:l=" ++ showGhc l)
    addDeltaAnnotation GHC.AnnDeriving
    addDeltaAnnotation GHC.AnnOpenP
    mapM_ annotatePC ts
    addDeltaAnnotation GHC.AnnCloseP
    addDeltaAnnotation GHC.AnnDarrow

-- ---------------------------------------------------------------------

instance (GHC.DataId name,AnnotateGen name,GHC.OutputableBndr name)
      => AnnotateGen (GHC.ConDecl name) where
  annotateG _ (GHC.ConDecl lns _expr (GHC.HsQTvs _ns bndrs) ctx
                         dets res _ _) = do
    case res of
      GHC.ResTyH98 -> do
        addDeltaAnnotation GHC.AnnForall
        mapM_ annotatePC bndrs
        addDeltaAnnotation GHC.AnnDot

        annotatePC ctx
        addDeltaAnnotation GHC.AnnDarrow

        case dets of
          GHC.InfixCon _ _ -> return ()
          _ -> mapM_ annotatePC lns

        annotateHsConDeclDetails lns dets

      GHC.ResTyGADT ls ty -> do
        -- only print names if not infix
        case dets of
          GHC.InfixCon _ _ -> return ()
          _ -> mapM_ annotatePC lns

        annotateHsConDeclDetails lns dets

        addDeltaAnnotation GHC.AnnDcolon

        annotatePC (GHC.L ls (ResTyGADTHook bndrs))

        annotatePC ctx
        addDeltaAnnotation GHC.AnnDarrow

        annotatePC ty


    addDeltaAnnotation GHC.AnnVbar

-- ---------------------------------------------------------------------

instance (GHC.DataId name,GHC.OutputableBndr name,AnnotateGen name) =>
              AnnotateGen (ResTyGADTHook name) where
  annotateG _ (ResTyGADTHook bndrs) = do
    addDeltaAnnotation GHC.AnnForall
    mapM_ annotatePC bndrs
    addDeltaAnnotation GHC.AnnDot

-- ---------------------------------------------------------------------

instance (AnnotateGen name,AnnotateGen a)
  => AnnotateGen (GHC.HsRecField name (GHC.Located a)) where
  annotateG _ (GHC.HsRecField n e _) = do
    annotatePC n
    addDeltaAnnotation GHC.AnnEqual
    annotatePC e

-- ---------------------------------------------------------------------

instance (GHC.DataId name,AnnotateGen name)
    => AnnotateGen (GHC.FunDep (GHC.Located name)) where

  annotateG _ (ls,rs) = do
    mapM_ annotatePC ls
    addDeltaAnnotation GHC.AnnRarrow
    mapM_ annotatePC rs

-- ---------------------------------------------------------------------

instance AnnotateGen (GHC.CType) where
  annotateG _ (GHC.CType src mh f) = do
    printAnnString GHC.AnnOpen src
    case mh of
      Nothing -> return ()
      Just (GHC.Header h) ->
         printAnnString GHC.AnnHeader ("\"" ++ GHC.unpackFS h ++ "\"")
    printAnnString GHC.AnnVal ("\"" ++ GHC.unpackFS f ++ "\"")
    printAnnString GHC.AnnClose "#-}"

-- ---------------------------------------------------------------------
