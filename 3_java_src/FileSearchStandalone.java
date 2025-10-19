import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;


public class FileSearchStandalone {

    public static void main(String[] args) {
        if (args == null || args.length == 0 || hasHelp(args)) {
            printUsageAndExit(0);
        }

        String file = null;
        String keyword = null;
        String column = "title";
        boolean caseSensitive = false;
        boolean printMatches = false;
        Long limit = null;


        for (int i = 0; i < args.length; i++) {
            String a = args[i];
            switch (a) {
                case "--file":
                    file = expectArg(args, ++i, "--file requires a value");
                    break;
                case "--keyword":
                    keyword = expectArg(args, ++i, "--keyword requires a value");
                    break;
                case "--column":
                    column = expectArg(args, ++i, "--column requires a value");
                    break;
                case "--case-sensitive":
                    caseSensitive = true;
                    break;
                case "--limit":
                    limit = parseLong(expectArg(args, ++i, "--limit requires a number"), "--limit must be a number");
                    break;
                case "--print":
                    printMatches = true;
                    break;
                default:
                    if (a.startsWith("--")) {
                        fail("Unknown argument: " + a);
                    } else {
                        fail("Unexpected token: " + a);
                    }
            }
        }

        requireNonEmpty(file, "--file is required");
        requireNonEmpty(keyword, "--keyword is required");
        requireNonEmpty(column, "--column must not be empty");

        try {
            runSearch(file, column, keyword, caseSensitive, printMatches, limit);
        } catch (Exception e) {
            System.err.println("Search failed: " + e.getMessage());
            e.printStackTrace(System.err);
            System.exit(2);
        }
    }

    private static void runSearch(String file,
                                  String column,
                                  String keyword,
                                  boolean caseSensitive,
                                  boolean printMatches,
                                  Long limit) throws IOException {
        long scanned = 0L;
        long matched = 0L;

        int colIdx = -1;
        Instant start = Instant.now();

        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(new FileInputStream(file), StandardCharsets.UTF_8),
                1 << 20)) {


            String header = br.readLine();
            if (header == null) {
                throw new IllegalStateException("Empty file: " + file);
            }
            List<String> headerCols = parseCsvLine(header);
            colIdx = indexOfIgnoreCase(headerCols, column);
            if (colIdx < 0) {
                throw new IllegalStateException("Column not found in header: '" + column + "'. Header: " + header);
            }


            String line;
            while ((line = br.readLine()) != null) {
                scanned++;
                if (limit != null && scanned > limit) {
                    break;
                }
                List<String> cols = parseCsvLine(line);
                String val = (colIdx < cols.size() ? cols.get(colIdx) : null);
                if (containsWithCaseOption(val, keyword, caseSensitive)) {
                    matched++;
                    if (printMatches) {
                        System.out.println(line);
                    }
                }
            }
        }

        Instant end = Instant.now();
        long millis = Duration.between(start, end).toMillis();


        System.out.println("== File Search Summary ==");
        System.out.println("  File           : " + file);
        System.out.println("  Column         : " + column);
        System.out.println("  Keyword        : " + keyword + (caseSensitive ? " (case-sensitive)" : " (case-insensitive)"));
        if (limit != null) System.out.println("  Limit          : " + limit + " data rows");
        System.out.println("  Scanned rows   : " + scanned);
        System.out.println("  Matches        : " + matched);
        System.out.println("  Elapsed        : " + millis + " ms");
        if (millis > 0) {
            double rps = scanned * 1000.0 / millis;
            System.out.printf("  Throughput     : %.2f rows/sec%n", rps);
        }
    }

    private static boolean hasHelp(String[] args) {
        for (String a : args) {
            if ("-h".equals(a) || "--help".equals(a) || "help".equalsIgnoreCase(a)) return true;
        }
        return false;
    }

    private static void printUsageAndExit(int code) {
        String usage = String.join("\n",
            "Usage:",
            "  java FileSearchStandalone --file <movies.csv> --keyword <kw> [--column <title>] [--case-sensitive] [--limit <N>] [--print]",
            "",
            "Options:",
            "  --file <path>          Path to CSV file (must contain a header row)",
            "  --keyword <kw>         Substring to search for",
            "  --column <name>        Column name to search (default: title, case-insensitive header match)",
            "  --case-sensitive       Enable case-sensitive matching (default: case-insensitive)",
            "  --limit <N>            Only scan the first N data rows (excluding header)",
            "  --print                Print matching rows (off by default to avoid timing distortion)",
            "  -h, --help             Show this help",
            "",
            "Examples:",
            "  javac -d out 3_java_src/FileSearchStandalone.java",
            "  java -cp out FileSearchStandalone --file 1_data/movies.csv --keyword \"STAR\"",
            "  java -cp out FileSearchStandalone --file 1_data/movies.csv --keyword \"STAR\" --case-sensitive",
            "  java -cp out FileSearchStandalone --file 1_data/movies.csv --keyword \"xxx\" --limit 100000",
            "  java -cp out FileSearchStandalone --file 1_data/movies.csv --keyword \"xxx\" --print"
        );
        System.out.println(usage);
        System.exit(code);
    }



    private static String expectArg(String[] args, int idx, String err) {
        if (idx < 0 || idx >= args.length) fail(err);
        return args[idx];
    }

    private static long parseLong(String s, String err) {
        try {
            return Long.parseLong(s.trim());
        } catch (NumberFormatException e) {
            fail(err + ": " + s);
            return 0;
        }
    }

    private static void requireNonEmpty(String s, String msg) {
        if (s == null || s.isEmpty()) fail(msg);
    }

    private static void fail(String msg) {
        throw new IllegalArgumentException(msg);
    }

    private static int indexOfIgnoreCase(List<String> cols, String name) {
        if (cols == null || name == null) return -1;
        for (int i = 0; i < cols.size(); i++) {
            if (name.equalsIgnoreCase(cols.get(i))) return i;
        }
        return -1;
    }

    private static boolean containsWithCaseOption(String text, String needle, boolean caseSensitive) {
        if (text == null) return false;
        if (needle == null || needle.isEmpty()) return true;
        return caseSensitive ? text.contains(needle) : text.toLowerCase().contains(needle.toLowerCase());
    }


    private static List<String> parseCsvLine(String line) {
        List<String> out = new ArrayList<>();
        if (line == null || line.isEmpty()) {
            out.add("");
            return out;
        }

        StringBuilder cur = new StringBuilder(line.length());
        boolean inQuotes = false;

        for (int i = 0; i < line.length(); i++) {
            char ch = line.charAt(i);
            if (inQuotes) {
                if (ch == '"') {
                    boolean hasNext = (i + 1) < line.length();
                    if (hasNext && line.charAt(i + 1) == '"') {
                        cur.append('"');
                        i++;
                    } else {
                        inQuotes = false;
                    }
                } else {
                    cur.append(ch);
                }
            } else {
                if (ch == '"') {
                    inQuotes = true;
                } else if (ch == ',') {
                    out.add(cur.toString());
                    cur.setLength(0);
                } else {
                    cur.append(ch);
                }
            }
        }
        out.add(cur.toString());
        return out;
    }
}
