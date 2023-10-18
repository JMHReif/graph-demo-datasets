///usr/bin/env jbang "$0" "$@" ; exit $?
//DEPS com.squareup.okhttp3:okhttp:4.11.0
//DEPS org.json:json:20230618

import static java.lang.System.*;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import java.io.IOException;
import java.io.FileWriter;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONArray;
import java.util.concurrent.TimeUnit;

public class travelPetDataImport {
    private static String googleApiKey = "<YOUR API KEY HERE>";
    private static String yelpApiKey = "<YOUR API KEY HERE>";
    public static String filename = "";

    public static void main(String... args) {
        searchGooglePlacesAPI(googleApiKey);
        searchYelpFusionAPI(yelpApiKey);
        searchAirbnbListingsAPI();
    }

    public static void searchGooglePlacesAPI(String googleApiKey) {
        filename = "googleApi.json";
        //https://apidocs.geoapify.com/docs/places/#categories
        String[] googleCategories = {"commercial","catering","accommodation","leisure","natural","pet","building","beach","tourism"};
        String location = "513cbd5296217e52c059cf66d5e76a574440c00208e2031d77686f736f6e66697273743a6c6f63616c6974793a3835393737353339";

        try {
            JSONObject json = new JSONObject();
            JSONArray jsonArray = new JSONArray();
            String jsonData = "";
            OkHttpClient client = new OkHttpClient().newBuilder().connectTimeout(30, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS).build();

            for (String category : googleCategories) {
                System.out.println("Google - " + category);

                Request request = new Request.Builder()
                        .url("https://api.geoapify.com/v2/places?categories=" + category + "&conditions=dogs&filter=place:" + location + "&limit=100&apiKey=" + googleApiKey)
                        .method("GET", null)
                        .build();
                Response response = client.newCall(request).execute();

                jsonData = response.body().string();

                JSONObject obj = new JSONObject(jsonData);
                JSONArray array = obj.getJSONArray("features");
                JSONObject place = new JSONObject();
                int n = array.length();
                for (int i = 0; i < n; ++i) {
                    place = array.getJSONObject(i);

                    if (!place.isEmpty()) {
                        json.append(category, place);
                    }
                }
            }

            FileWriter myWriter = new FileWriter(filename);
            myWriter.write(json.toString(4));
            myWriter.close();
            System.out.println("Successfully wrote to Google file.");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public static void searchYelpFusionAPI(String yelpApiKey) {
        filename = "yelpApi.json";
        //https://docs.developer.yelp.com/docs/resources-categories
        String[] yelpCategories = {"active","arts","food","hotelstravel","nightlife","pets","restaurants","shopping"};
        String location = "New%20York%20City";

        try {
            JSONObject json = new JSONObject();
            JSONArray jsonArray = new JSONArray();
            String jsonData = "";
            OkHttpClient client = new OkHttpClient().newBuilder().connectTimeout(20, TimeUnit.SECONDS).build();
            for (String category : yelpCategories) {
                System.out.println("Yelp - " + category);

                Request request = new Request.Builder()
                        .url("https://api.yelp.com/v3/businesses/search?location=" + location + "&categories=" + category + "&attributes=dogs_allowed&limit=50&sort_by=distance")
                        .get()
                        .addHeader("accept", "application/json")
                        .addHeader("Authorization", "Bearer " + yelpApiKey)
                        .build();
                Response response = client.newCall(request).execute();

                jsonData = response.body().string();

                JSONObject obj = new JSONObject(jsonData);
                JSONArray array = obj.getJSONArray("businesses");
                JSONObject place = new JSONObject();
                int n = array.length();
                for (int i = 0; i < n; ++i) {
                    place = array.getJSONObject(i);

                    if (!place.isEmpty()) {
                        json.append(category, place);
                    }
                }
            }

            FileWriter myWriter = new FileWriter(filename);
            myWriter.write(json.toString(4));
            myWriter.close();
            System.out.println("Successfully wrote to Yelp file.");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public static void searchAirbnbListingsAPI() {
        filename = "airbnbApi.json";
        int total = 0;
        int limit = 100;
        int offset = 0;
        int max = 10000;
        int batch = 0;
        String location = "Chicago";
        String urlPrefix = "https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/airbnb-listings/records?where=%22dog%22%20OR%20%22cat%22%20AND%20%22" + location + "%22&limit=";

        try {
            JSONObject json = new JSONObject();
            JSONArray jsonArray = new JSONArray();
            String jsonData = "";
            OkHttpClient client = new OkHttpClient().newBuilder().connectTimeout(20, TimeUnit.SECONDS).build();
            int totalBatches = (max/limit) - 1;

            while (offset+limit <= max) {
                System.out.println("Batch: " + batch++ + " of " + totalBatches);

                if (offset+limit == max) {
                    limit = (max-offset)-1;
                }

                Request request = new Request.Builder()
                        .url(urlPrefix + limit + "&offset=" + offset)
                        .method("GET", null)
                        .build();
                Response response = client.newCall(request).execute();

                jsonData = response.body().string();

                try {
                    JSONObject obj = new JSONObject(jsonData);

                    if (offset == 0) {
                        total = obj.getInt("total_count");
                        json.put("total_count", total);
                    }

                    JSONArray array = obj.getJSONArray("results");
                    JSONObject place = new JSONObject();
                    int n = array.length();
                    for (int i = 0; i < n; ++i) {
                        place = array.getJSONObject(i);

                        if (!place.isEmpty()) {
                            json.append("results", place);
                        }
                    }

                    FileWriter myWriter = new FileWriter(filename);
                    myWriter.write(json.toString(4));
                    myWriter.close();

                    offset += limit;
                } catch (JSONException e) {
                    e.printStackTrace();
                    System.out.println(jsonData);
                    break;
                }
            }
            System.out.println("Successfully wrote to Airbnb file.");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
