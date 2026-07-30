# PRISMA-LANGUAGE: Syntax & AST Canonicalization Specification

**Document Identifier**: `PRISMA-LANGUAGE`  
**Status**: Frozen Technical Specification v1.0  

---

## 1. EBNF Surface Grammar Definition

```ebnf
Statement      ::= AssertStmt | RuleStmt | QueryStmt ;
AssertStmt     ::= "ASSERT" FactExpr "IN" ContextRef ;
RuleStmt       ::= "RULE" RuleID "IF" Antecedent "THEN" Consequent ;
QueryStmt      ::= ("QUERY" | "WHY" | "HOW" | "WHEN") GoalExpr "IN" ContextRef ;

Antecedent     ::= Condition { ("AND" | "OR") Condition } ;
Condition      ::= PredicateName "(" TermList ")" | "NOT" Condition ;
Consequent     ::= PredicateName "(" TermList ")" ;

TermList       ::= Term { "," Term } ;
Term           ::= Variable | Identifier | Literal ;
Variable       ::= "?" [a-zA-Z0-9_]+ ;
Identifier     ::= [a-zA-Z0-9_:]+ ;
Literal        ::= StringLiteral | NumberLiteral | BooleanLiteral ;
ContextRef     ::= "prisma:context:" [a-zA-Z0-9_:/-]+ ;
```

---

## 2. Canonical Primitive Constraints (PIP-006 & PIP-007 Normative Standards)

1. **ContextID Constraint**: Every `ContextRef` MUST match regex `^prisma:context:[a-zA-Z0-9_\:\/\-]+$`.
2. **Numeric Canonicalization (PIP-006)**: Numbers in JSON AST MUST follow RFC 8785 rules. Integer numbers MUST NOT contain fractional parts (e.g. `20`, NOT `20.0`). Floating point `-0.0` MUST be converted to `0` prior to serialization. Non-finite values (`NaN`, `Infinity`, `-Infinity`) are strictly FORBIDDEN in PRISMA ASTs.
3. **Identifier Case Sensitivity (PIP-007)**: All `Identifier`, `ContextRef`, and `PredicateName` strings MUST be compared using exact binary UTF-8 byte matching (case-sensitive).
4. **AST Key Lexicographical Sorting**: All JSON AST object keys MUST be sorted in ascending ASCII lexicographical order prior to SHA-256 calculation (`PO-1`).

---

## 3. AST 1:1 Mapping & Canonicalization (RFC 8785)

Any PL statement compiles deterministically to a canonical JSON AST. Key sorting is lexicographical:

```json
{
  "kind": "ImplicationRule",
  "operator": "implies",
  "antecedent": {
    "operator": "AND",
    "operands": [
      { "operator": ">=", "subject": "edad", "value": 18 },
      { "operator": "=", "subject": "jurisdiccion", "value": "Colombia" }
    ]
  },
  "consequent": {
    "operator": "=",
    "subject": "esMayorDeEdad",
    "value": true
  }
}
```
