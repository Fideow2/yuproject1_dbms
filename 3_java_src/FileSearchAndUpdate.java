

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.Closeable;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;


public class FileSearchAndUpdate {

    public static void main(String[] args) {
        if (args.length == 0) {
            printUsageAndExit(0);
            return;
        }

        String cmd = args[0].trim().toLowerCase();
        String[] rest = slice(args, 1);

        try {
            switch (cmd) {
                case "preview":
                    cmdPreview(rest);
                    break;
                case "search-movies":
                    cmdSearchMovies(rest);
                    break;
                case "update-persons":
                    cmdUpdatePersons(rest);
                    break;
                case "help":
                case "--help":
                case "-h":
                    printUsageAndExit(0);
                    break;
                default:
                    System.err.println("Unknown command: " + cmd);
                    printUsageAndExit(1);
                    break;
            }
        } catch (Exception ex) {
            System.err.println("Operation failed: " + ex.getMessage());
            ex.printStackTrace(System.err);
            System.exit(2);
        }
    }

    
    
    
    private static void cmdPreview(String[] args) throws IOException {
        String file = null;
        int lines = 10;

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--file":
                    file = expectArg(args, ++i, "--file requires a value");
                    break;
                case "--lines":
                    lines = Integer.parseInt(expectArg(args, ++i, "--lines requires a number"));
                    break;
                default:
                    throw new IllegalArgumentException("Unknown argument for preview: " + args[i]);
            }
        }

        requireNonEmpty(file, "--file is required");

        System.out.println("== Preview: " + file + " (first " + lines + " lines) ==");
        try (BufferedReader br = newBufferedReader(file)) {
            String line;
            int count = 0;
            while ((line = br.readLine()) != null && count < lines) {
                System.out.println(line);
                count++;
            }
        }
    }

    
    
    
    private static void cmdSearchMovies(String[] args) throws IOException {
        String file = null;
        String keyword = null;
        boolean caseSensitive = false;
        Long limit = null; 

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--file":
                    file = expectArg(args, ++i, "--file requires a value");
                    break;
                case "--keyword":
                    keyword = expectArg(args, ++i, "--keyword requires a value");
                    break;
                case "--case-sensitive":
                    caseSensitive = true;
                    break;
                case "--limit":
                    limit = Long.parseLong(expectArg(args, ++i, "--limit requires a number"));
                    break;
                default:
                    throw new IllegalArgumentException("Unknown argument for search-movies: " + args[i]);
            }
        }

        requireNonEmpty(file, "--file is required");
        requireNonEmpty(keyword, "--keyword is required");

        Instant start = Instant.now();
        long matched = 0L;
        long scanned = 0L;
        int titleIdx = -1;

        try (BufferedReader br = newBufferedReader(file)) {
            String header = br.readLine();
            if (header == null) {
                System.out.println("Empty file. Nothing to search.");
                return;
            }
            List<String> headerCols = parseCsvLine(header);
            titleIdx = indexOfIgnoreCase(headerCols, "title");
            if (titleIdx < 0) {
                throw new IllegalStateException("Cannot find 'title' column in header: " + header);
            }

            String line;
            while ((line = br.readLine()) != null) {
                scanned++;
                if (limit != null && scanned > limit) {
                    break;
                }
                List<String> cols = parseCsvLine(line);
                if (titleIdx >= cols.size()) {
                    
                    continue;
                }
                String title = cols.get(titleIdx);
                if (containsWithCaseOption(title, keyword, caseSensitive)) {
                    matched++;
                }
            }
        }

        Instant end = Instant.now();
        long millis = Duration.between(start, end).toMillis();

        System.out.println("Search complete.");
        System.out.println("  File: " + file);
        System.out.println("  Keyword: " + keyword + (caseSensitive ? " (case-sensitive)" : " (case-insensitive)"));
        if (limit != null) {
            System.out.println("  Limit: " + limit + " lines (data rows excluding header)");
        }
        System.out.println("  Scanned rows: " + scanned);
        System.out.println("  Matches: " + matched);
        System.out.println("  Elapsed: " + millis + " ms");
        if (millis > 0) {
            double rowsPerSec = (scanned * 1000.0) / millis;
            System.out.printf("  Throughput: %.2f rows/sec%n", rowsPerSec);
        }
    }

    
    
    
    private static void cmdUpdatePersons(String[] args) throws IOException {
        String input = null;
        String output = null;
        String from = null;
        String to = null;
        boolean inPlace = false;
        String backupExt = ".bak";
        boolean caseInsensitive = false;
        Long limit = null; 

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--input":
                    input = expectArg(args, ++i, "--input requires a value");
                    break;
                case "--output":
                    output = expectArg(args, ++i, "--output requires a value");
                    break;
                case "--from":
                    from = expectArg(args, ++i, "--from requires a value");
                    break;
                case "--to":
                    to = expectArg(args, ++i, "--to requires a value");
                    break;
                case "--in-place":
                    inPlace = true;
                    break;
                case "--backup":
                    backupExt = expectArg(args, ++i, "--backup requires a value like .bak");
                    break;
                case "--case-insensitive":
                    caseInsensitive = true;
                    break;
                case "--limit":
                    limit = Long.parseLong(expectArg(args, ++i, "--limit requires a number"));
                    break;
                default:
                    throw new IllegalArgumentException("Unknown argument for update-persons: " + args[i]);
            }
        }

        requireNonEmpty(input, "--input is required");
        requireNonEmpty(from, "--from is required");
        requireNonEmpty(to, "--to is required");

        File inFile = new File(input);
        if (!inFile.isFile()) {
            throw new IllegalArgumentException("Input is not a file: " + input);
        }

        File outFile;
        boolean tempUsed = false;

        if (inPlace) {
            
            outFile = new File(inFile.getParentFile(), inFile.getName() + ".tmp.updating");
            tempUsed = true;
        } else {
            requireNonEmpty(output, "--output is required when not using --in-place");
            outFile = new File(output);
            if (outFile.isDirectory()) {
                throw new IllegalArgumentException("--output points to a directory, expected a file path");
            }
        }

        Instant start = Instant.now();
        long scanned = 0L;
        long updated = 0L;
        int nameIdx = -1;
        List<String> headerCols;

        try (BufferedReader br = newBufferedReader(input);
             BufferedWriter bw = newBufferedWriter(outFile.getAbsolutePath())) {

            String header = br.readLine();
            if (header == null) {
                
                
            } else {
                headerCols = parseCsvLine(header);
                nameIdx = indexOfIgnoreCase(headerCols, "person_name");
                if (nameIdx < 0) {
                    
                    
                    throw new IllegalStateException("Cannot find 'person_name' column in header: " + header);
                }
                bw.write(header);
                bw.write('\n');
            }

            String line;
            while ((line = br.readLine()) != null) {
                scanned++;
                if (limit != null && scanned > limit) {
                    break;
                }
                List<String> cols = parseCsvLine(line);
                if (nameIdx >= 0 && nameIdx < cols.size()) {
                    String original = cols.get(nameIdx);
                    String replaced = caseInsensitive
                            ? replaceAllCaseInsensitive(original, from, to)
                            : original.replace(from, to);
                    if (!original.equals(replaced)) {
                        updated++;
                        cols.set(nameIdx, replaced);
                    }
                }
                bw.write(toCsvLine(cols));
                bw.write('\n');
            }
        } catch (IOException ioe) {
            
            if (tempUsed && outFile.exists()) {
                outFile.delete();
            }
            throw ioe;
        }

        
        if (inPlace) {
            File backupFile = new File(inFile.getAbsolutePath() + backupExt);
            if (backupFile.exists() && !backupFile.delete()) {
                throw new IOException("Failed to delete existing backup: " + backupFile.getAbsolutePath());
            }
            if (!inFile.renameTo(backupFile)) {
                
                copyFile(inFile, backupFile);
                if (!inFile.delete()) {
                    throw new IOException("Failed to delete original after backup copy: " + inFile.getAbsolutePath());
                }
            }
            File finalFile = new File(inFile.getAbsolutePath());
            if (!outFile.renameTo(finalFile)) {
                
                copyFile(outFile, finalFile);
                if (!outFile.delete()) {
                    throw new IOException("Failed to delete temp file after manual move: " + outFile.getAbsolutePath());
                }
            }
        }

        Instant end = Instant.now();
        long millis = Duration.between(start, end).toMillis();

        System.out.println("Update complete.");
        System.out.println("  Input: " + input);
        System.out.println("  Output: " + (inPlace ? input + " (in-place with backup " + backupExt + ")" : outFile.getAbsolutePath()));
        System.out.println("  Replacement: '" + from + "' -> '" + to + "'" + (caseInsensitive ? " (case-insensitive)" : " (case-sensitive)"));
        if (limit != null) {
            System.out.println("  Limit: " + limit + " lines (data rows excluding header)");
        }
        System.out.println("  Scanned rows: " + scanned);
        System.out.println("  Updated rows: " + updated);
        System.out.println("  Elapsed: " + millis + " ms");
        if (millis > 0) {
            double rowsPerSec = (scanned * 1000.0) / millis;
            System.out.printf("  Throughput: %.2f rows/sec%n", rowsPerSec);
        }
    }

    
    
    

    private static BufferedReader newBufferedReader(String path) throws IOException {
        return new BufferedReader(new InputStreamReader(new FileInputStream(path), StandardCharsets.UTF_8), 1 << 20);
    }

    private static BufferedWriter newBufferedWriter(String path) throws IOException {
        return new BufferedWriter(new OutputStreamWriter(new FileOutputStream(path), StandardCharsets.UTF_8), 1 << 20);
    }

    private static int indexOfIgnoreCase(List<String> cols, String name) {
        for (int i = 0; i < cols.size(); i++) {
            if (name.equalsIgnoreCase(cols.get(i))) {
                return i;
            }
        }
        return -1;
    }

    private static String expectArg(String[] args, int idx, String err) {
        if (idx < 0 || idx >= args.length) {
            throw new IllegalArgumentException(err);
        }
        return args[idx];
    }

    private static void requireNonEmpty(String s, String msg) {
        if (s == null || s.isEmpty()) {
            throw new IllegalArgumentException(msg);
        }
    }

    private static String[] slice(String[] arr, int from) {
        if (from <= 0) return arr;
        if (from >= arr.length) return new String[0];
        String[] out = new String[arr.length - from];
        System.arraycopy(arr, from, out, 0, out.length);
        return out;
    }

    private static void printUsageAndExit(int code) {
        String usage = ""
            + "Usage:\n"
            + "  preview --file <path> [--lines <N>]\n"
            + "  search-movies --file <movies.csv> --keyword <kw> [--case-sensitive] [--limit <N>]\n"
            + "  update-persons --input <persons.csv> (--output <out.csv> | --in-place [--backup <.bak>]) --from <s> --to <s> [--case-insensitive] [--limit <N>]\n"
            + "\n"
            + "Examples:\n"
            + "  java FileSearchAndUpdate preview --file yuproject1/1_data/movies.csv --lines 10\n"
            + "  java FileSearchAndUpdate search-movies --file yuproject1/1_data/movies.csv --keyword \"STAR\"\n"
            + "  java FileSearchAndUpdate update-persons --input yuproject1/1_data/persons.csv --output /tmp/persons_updated.csv --from \"To\" --to \"TTOO\"\n"
            + "  java FileSearchAndUpdate update-persons --input yuproject1/1_data/persons.csv --in-place --backup \".bak\" --from \"To\" --to \"TTOO\"\n"
        System.out.println(usage);
        System.exit(code);
    }

    
    
    

    
    private static List<String> parseCsvLine(String line) {
        List<String> out = new ArrayList<>();
        if (line == null) {
            return out;
        }

        StringBuilder cur = new StringBuilder();
        boolean inQuotes = false;
        int i = 0;
        while (i < line.length()) {
            char ch = line.charAt(i);
            if (inQuotes) {
                if (ch == '"') {
                    if (i + 1 < line.length() && line.charAt(i + 1) == '"') {
                        
                        cur.append('"');
                        i += 2;
                    } else {
                        
                        inQuotes = false;
                        i++;
                    }
                } else {
                    cur.append(ch);
                    i++;
                }
            } else {
                if (ch == '"') {
                    inQuotes = true;
                    i++;
                } else if (ch == ',') {
                    out.add(cur.toString());
                    cur.setLength(0);
                    i++;
                } else {
                    cur.append(ch);
                    i++;
                }
            }
        }
        out.add(cur.toString());
        return out;
    }

    
    private static String toCsvLine(List<String> fields) {
        StringBuilder sb = new StringBuilder();
        for (int idx = 0; idx < fields.size(); idx++) {
            if (idx > 0) sb.append(',');
            sb.append(quoteCsvField(fields.get(idx)));
        }
        return sb.toString();
    }

    private static String quoteCsvField(String s) {
        if (s == null) s = "";
        boolean needQuote = false;
        for (int i = 0; i < s.length(); i++) {
            char ch = s.charAt(i);
            if (ch == ',' || ch == '"' || ch == '\n' || ch == '\r') {
                needQuote = true;
                break;
            }
        }
        if (!needQuote) {
            return s;
        }
        
        String escaped = s.replace("\"", "\"\"");
        return "\"" + escaped + "\"";
    }

    private static boolean containsWithCaseOption(String text, String needle, boolean caseSensitive) {
        if (text == null) return false;
        if (needle == null || needle.isEmpty()) return true;
        return caseSensitive
                ? text.contains(needle)
                : text.toLowerCase().contains(needle.toLowerCase());
    }

    private static String replaceAllCaseInsensitive(String input, String from, String to) {
        if (input == null || input.isEmpty() || from == null || from.isEmpty()) {
            return input;
        }
        
        String lowerInput = input.toLowerCase();
        String lowerFrom = from.toLowerCase();
        StringBuilder out = new StringBuilder(input.length());
        int i = 0;
        while (i < input.length()) {
            int idx = lowerInput.indexOf(lowerFrom, i);
            if (idx < 0) {
                out.append(input, i, input.length());
                break;
            } else {
                out.append(input, i, idx);
                out.append(to);
                i = idx + from.length();
            }
        }
        return out.toString();
    }

    private static void copyFile(File src, File dst) throws IOException {
        try (FileInputStream in = new FileInputStream(src);
             FileOutputStream out = new FileOutputStream(dst)) {
            byte[] buf = new byte[1 << 20];
            int r;
            while ((r = in.read(buf)) >= 0) {
                out.write(buf, 0, r);
            }
        }
    }

    @SuppressWarnings("unused")
    private static void closeQuietly(Closeable c) {
        if (c != null) try { c.close(); } catch (IOException ignored) {}
    }
}
